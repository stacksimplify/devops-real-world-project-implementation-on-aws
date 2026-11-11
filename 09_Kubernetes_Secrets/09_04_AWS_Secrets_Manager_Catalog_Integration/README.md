# Section 09-04: Integrate AWS Secrets Manager with Catalog Microservice (EKS Pod Identity)
In the previous [step (09-03)](../09_03_AWS_Secrets_Manager_Driver_Setup/), we installed the Secrets Store CSI Driver and AWS Secrets Provider (ASCP). Now, let’s use that setup to mount secrets directly from AWS Secrets Manager into our Catalog microservice.

In this section, we’ll securely connect **AWS Secrets Manager** with our Kubernetes Pods
to provide MySQL credentials **without ever storing them inside Kubernetes Secrets**.
This is the **production-grade, zero-trust setup** — credentials live only in AWS,
and are fetched dynamically inside the container via the **AWS Secrets and Configuration Provider (ASCP)**.

---  

## **Learning Objectives**

By the end of this step, you will:

* Create an **AWS Secrets Manager secret** (`catalog-db-secret-1`) with MySQL credentials.
* Define a **SecretProviderClass** that retrieves this secret using **EKS Pod Identity**.
* Update both the **MySQL StatefulSet** and **Catalog Deployment** to mount and use these secrets.
* Achieve **no plaintext credentials** or **Kubernetes Secrets** stored in etcd.

---

## Architecture Diagram
![AWS Secrets Manager for AWS EKS Cluster](../../images/09-03-AWS-Secrets-Manager-for-EKS.png)


---

## **Architecture Overview**

```
+------------------------------------+
| AWS Secrets Manager                |
| Secret: catalog-db-secret-1        |
| {                                  |
|   "MYSQL_USER":"catalog",          |
|   "MYSQL_PASSWORD":"MyS3cr3tPwd"   |
| }                                  |
+----------------+-------------------+
                 |
                 | (via EKS Pod Identity)
                 v
+-------------------------------------------+
| Amazon EKS Cluster                        |
|  - Pod Identity Agent                     |
|  - AWS Secrets & Config Provider (ASCP)   |
|  - catalog-mysql-sa (ServiceAccount)      |
|  - SecretProviderClass: catalog-db-secrets|
|                                           |
|  /mnt/secrets-store/MYSQL_USER            |
|  /mnt/secrets-store/MYSQL_PASSWORD        |
+-------------------------------------------+
```

---

## Step-01: Create AWS Secret in Secrets Manager

Before deploying Kubernetes manifests, create your AWS secret containing MySQL credentials.

### Command

```bash
# Replace <REGION> with your AWS Region (e.g., us-east-1)
export AWS_REGION="us-east-1"

# Create Secret 
aws secretsmanager create-secret \
  --name catalog-db-secret-1 \
  --region $AWS_REGION \
  --description "MySQL credentials for Catalog microservice" \
  --secret-string '{
      "MYSQL_USER": "mydbadmin",
      "MYSQL_PASSWORD": "kalyandb101"
  }'

# List all secrets in your account (filtered by name)
aws secretsmanager list-secrets --region $AWS_REGION --query "SecretList[?contains(Name, 'catalog-db-secret-1')].[Name,ARN]" --output table


# Describe the Secret for Details
aws secretsmanager describe-secret \
  --secret-id catalog-db-secret-1 \
  --region $AWS_REGION

# Retrieve Secret Value (for testing only)
aws secretsmanager get-secret-value \
  --secret-id catalog-db-secret-1 \
  --region $AWS_REGION \
  --query SecretString --output text
```

---


## Step-02: Create the SecretProviderClass

This tells ASCP which AWS secret to fetch and how to make it available to the container.

**File:** `01_secretproviderclass/01_catalog_secretproviderclass.yaml`

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: catalog-db-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "catalog-db-secret-1"
        objectType: "secretsmanager"
        jmesPath:
          - path: "MYSQL_USER"
            objectAlias: "MYSQL_USER"
          - path: "MYSQL_PASSWORD"
            objectAlias: "MYSQL_PASSWORD"
    usePodIdentity: "true"
```

✅ This configuration:

* Fetches `catalog-db-secret-1` from AWS Secrets Manager.
* Extracts `MYSQL_USER` and `MYSQL_PASSWORD` into **two files** under `/mnt/secrets-store`.
* Uses Pod Identity for authentication (no IRSA or node IAM role required).
* Does **not** create any native Kubernetes Secret — best-security mode.

---

## Step-03: Create the ServiceAccount

The ServiceAccount (`catalog-mysql-sa`) is already associated with an IAM Role
via Pod Identity, allowing Pods using this SA to authenticate to AWS.

**File:** `02_catalog_k8s_manifests/06_catalog_mysql_service_account.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog-mysql-sa
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: service
    app.kubernetes.io/owner: retail-store-sample
```

---


## Step-04: Update the MySQL StatefulSet

**File:** `02_catalog_k8s_manifests/04_catalog_statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: catalog-mysql
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: mysql
    app.kubernetes.io/owner: retail-store-sample
spec:
  replicas: 1
  serviceName: catalog-mysql
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
      app.kubernetes.io/instance: catalog
      app.kubernetes.io/component: mysql
      app.kubernetes.io/owner: retail-store-sample
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
        app.kubernetes.io/instance: catalog
        app.kubernetes.io/component: mysql
        app.kubernetes.io/owner: retail-store-sample
    spec:
      serviceAccount: catalog-mysql-sa
      containers:
        - name: mysql
          image: "public.ecr.aws/docker/library/mysql:8.0"
          imagePullPolicy: IfNotPresent
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: my-secret-pw
            - name: MYSQL_DATABASE
              value: catalogdb
          command: ["/bin/bash", "-c"]
          args:
            - |
              export MYSQL_USER=$(cat /mnt/secrets-store/MYSQL_USER);
              export MYSQL_PASSWORD=$(cat /mnt/secrets-store/MYSQL_PASSWORD);
              echo "Loaded secrets from AWS Secrets Manager. Starting MySQL with user=$MYSQL_USER";
              exec docker-entrypoint.sh mysqld
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
            - name: aws-secrets
              mountPath: /mnt/secrets-store
              readOnly: true
      volumes:
        - name: data
          emptyDir: {}
        - name: aws-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "catalog-db-secrets"
```

✅ Behavior:

* Reads credentials directly from AWS Secrets Manager.
* Credentials are never stored in Kubernetes.
* Safe even if etcd or the cluster is compromised.

---

## Step-05: Update the Catalog Microservice Deployment

**File:** `02_catalog_k8s_manifests/01_catalog_deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: service
    app.kubernetes.io/owner: retail-store-sample
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
      app.kubernetes.io/instance: catalog
      app.kubernetes.io/component: service
      app.kubernetes.io/owner: retail-store-sample
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
        app.kubernetes.io/instance: catalog
        app.kubernetes.io/component: service
        app.kubernetes.io/owner: retail-store-sample
    spec:
      serviceAccount: catalog-mysql-sa
      securityContext:
        fsGroup: 1000
      containers:
        - name: catalog
          envFrom:
            - configMapRef:
                name: catalog
          securityContext:
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
          image: "public.ecr.aws/aws-containers/retail-store-sample-catalog:1.3.0"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 256Mi
          volumeMounts:
            - name: aws-secrets
              mountPath: /mnt/secrets-store
              readOnly: true
          command: ["/bin/bash", "-c"]
          args:
            - |
              export RETAIL_CATALOG_PERSISTENCE_USER=$(cat /mnt/secrets-store/MYSQL_USER);
              export RETAIL_CATALOG_PERSISTENCE_PASSWORD=$(cat /mnt/secrets-store/MYSQL_PASSWORD);
              echo "Starting Catalog service with secure DB credentials";
              exec java -jar /app/catalog.jar
      volumes:
        - name: aws-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "catalog-db-secrets"
```

✅ Behavior:

* Fetches DB credentials securely via Pod Identity (same SA and IAM role).
* No Kubernetes Secret objects created or synced.
* Perfect isolation between AWS and EKS.

---

## Step-06: Apply All Kubernetes Manifests
```bash
# First: Deploy Secret Provider Class
kubectl apply -f 01_secretproviderclass

# Second: Deploy all our Catalog k8s Manifests
kubectl apply -f 02_catalog_k8s_manifests
```

---

## Step-07: Verify if Secrets mounted in pods or not
```bash
# MySQL Pod
kubectl exec -it <mysql-pod-name> -- ls /mnt/secrets-store
kubectl exec -it <mysql-pod-name> -- cat /mnt/secrets-store/MYSQL_USER
kubectl exec -it <mysql-pod-name> -- cat /mnt/secrets-store/MYSQL_PASSWORD


# Catalog Pod
kubectl exec -it <catalog-pod-name> -- ls /mnt/secrets-store
kubectl exec -it <catalog-pod-name> -- cat /mnt/secrets-store/RETAIL_CATALOG_PERSISTENCE_USER
kubectl exec -it <catalog-pod-name> -- cat /mnt/secrets-store/RETAIL_CATALOG_PERSISTENCE_PASSWORD
```


---

## Step-08: Verify Catalog Microservice Application
```bash
# List Pods
kubectl get pods

# Port-forward
kubectl port-forward svc/catalog-service 7080:8080

# Acess Catalog Endpoints
http://localhost:7080/topology
http://localhost:7080/health
http://localhost:7080/catalog/products
http://localhost:7080/catalog/size
http://localhost:7080/catalog/tags
```

--- 

## Step-09: Connect to MySQL Database and Verify
```bash
# Connect to MySQL Database using MySQL Client Pod
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h catalog-mysql -u mydbadmin -p

When prompted for password, enter: kalyandb101
```

### Run SQL Commands

```sql
SHOW DATABASES;
USE catalogdb;
SHOW TABLES;
SELECT * FROM products;
SELECT * FROM tags;
SELECT * FROM product_tags;
EXIT;
```

---

## Step-10: Clean-Up - Delete Kubernetes Resources
```bash
# Delete Kubetnetes Resources
kubectl delete -f 02_catalog_k8s_manifests

# Delete Secret Provider class
kubectl delete -f 01_secretproviderclass
```

---

## Step-11: Summary

| Component               | File                                               | Purpose                                               | Security Level            |
| ----------------------- | -------------------------------------------------- | ----------------------------------------------------- | ------------------------- |
| **AWS Secret**          | —                                                  | Source of truth for credentials                       | 🔒 Stored securely in AWS |
| **ServiceAccount**      | `02_catalog_k8s_manifests/06_catalog_mysql_service_account.yaml` | Binds IAM Role via Pod Identity                       | ✅ IAM-based               |
| **SecretProviderClass** | `01_secretproviderclass/01_catalog_secretproviderclass.yaml`     | Defines which AWS secret to mount using Pod Identity  | 🔒 No sync to etcd        |
| **MySQL StatefulSet**   | `02_catalog_k8s_manifests/04_catalog_statefulset.yaml`           | Reads credentials from mounted secret files           | ✅ Secure runtime          |
| **Catalog Deployment**  | `02_catalog_k8s_manifests/01_catalog_deployment.yaml`            | Reads credentials from mounted secret files           | ✅ Secure runtime          |

---

## Additional Reference
- [secrets-store-csi-driver-provider-aws](https://github.com/aws/secrets-store-csi-driver-provider-aws)

---
