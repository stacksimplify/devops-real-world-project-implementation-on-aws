# 📖 Docsify Documentation Site

This folder contains the Docsify-powered documentation site for the Ultimate DevOps Real-World Project course.

## 🌐 Live Site

**Production URL:** https://stacksimplify.github.io/devops-real-world-project-implementation-on-aws/

## 📁 Structure

```
docs/
├── index.html          # Main Docsify configuration
├── _coverpage.md       # Landing page/cover
├── _sidebar.md         # Navigation sidebar (auto-generated)
├── .nojekyll           # GitHub Pages configuration
└── README.md          # This file
```

## 🔄 Auto-Generation

The sidebar (`_sidebar.md`) is **automatically generated** from the repository structure using `generate_sidebar.py` in the root directory.

### When Sidebar Updates

The sidebar is regenerated automatically via GitHub Actions when:
- Any README.md file is added, modified, or deleted
- New course sections are added
- The `generate_sidebar.py` script is updated
- Manual trigger from GitHub Actions

### Manual Regeneration

To manually regenerate the sidebar:

```bash
# From repository root
python generate_sidebar.py
```

## 🎨 Customization

### Styling

All styling is in `index.html` within the `<style>` tag. Key CSS variables:

```css
:root {
  --theme-color: #FF6B35;          /* Primary brand color */
  --theme-color-dark: #E85D2A;     /* Darker shade */
  --theme-color-light: #FF8C61;    /* Lighter shade */
  --sidebar-width: 300px;          /* Sidebar width */
}
```

### Plugins

Currently enabled plugins:
- ✅ Search (full-text search across all content)
- ✅ Pagination (prev/next navigation)
- ✅ Copy Code (copy button for code blocks)
- ✅ Zoom Image (click to zoom images)
- ✅ Emoji (emoji support)
- ✅ Syntax Highlighting (for multiple languages)

To add more plugins, add the script tag in `index.html`.

### Cover Page

Edit `_coverpage.md` to update:
- Course description
- Key features
- Statistics
- Call-to-action buttons

## 🚀 Local Development

### Option 1: Using Docsify CLI (Recommended)

```bash
# Install docsify-cli globally
npm i docsify-cli -g

# Serve the docs locally
cd docs
docsify serve

# Open http://localhost:3000
```

### Option 2: Using Python HTTP Server

```bash
# From docs directory
python -m http.server 3000

# Open http://localhost:3000
```

### Option 3: Using VS Code Live Server

1. Install "Live Server" extension in VS Code
2. Right-click on `docs/index.html`
3. Select "Open with Live Server"

## 📝 Content Management

### Adding New Sections

1. Create your section folder in repo root (e.g., `19_NEW_SECTION/`)
2. Add README.md files in subdirectories
3. Update `SECTIONS` list in `generate_sidebar.py`
4. Commit and push - sidebar auto-updates!

### Best Practices

- ✅ Keep README.md files focused and well-structured
- ✅ Use relative links within README files
- ✅ Include images in appropriate folders
- ✅ Use markdown features (tables, code blocks, lists)
- ✅ Add emojis for visual appeal
- ❌ Don't edit `_sidebar.md` manually (it's auto-generated)

## 🔍 Search Configuration

Search is configured to:
- Index all content automatically
- Cache for 1 day (improves performance)
- Search depth of 6 levels
- Highlight matches
- Show context around matches

## 📱 Mobile Responsiveness

The site is fully responsive and works great on:
- 📱 Mobile phones
- 📱 Tablets
- 💻 Laptops
- 🖥️ Desktop monitors

## 🐛 Troubleshooting

### Sidebar not updating

```bash
# Manually regenerate
python generate_sidebar.py

# Check GitHub Actions logs
# Go to: Repository → Actions → Deploy Docsify Documentation
```

### Images not loading

Ensure image paths are correct:
```markdown
<!-- Relative to README location -->
![diagram](./images/architecture.png)

<!-- Absolute from docs root -->
![logo](/images/logo.png)
```

### 404 errors

- Ensure `.nojekyll` file exists in docs folder
- Check that file paths match exactly (case-sensitive)
- Verify GitHub Pages is enabled in repo settings

## 🛠️ Advanced Configuration

### Adding Google Analytics

Edit `index.html` and uncomment the Google Analytics section:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=YOUR-GA-ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'YOUR-GA-ID');
</script>
```

### Custom Domain

To use a custom domain:

1. Add CNAME file in docs folder:
   ```
   docs.stacksimplify.com
   ```

2. Configure DNS with your provider:
   ```
   CNAME docs.stacksimplify.com stacksimplify.github.io
   ```

3. Enable custom domain in GitHub Pages settings

## 📊 Performance

The site is optimized for performance:
- ✅ No build step required (instant updates)
- ✅ CDN-hosted assets
- ✅ Lazy loading of content
- ✅ Search index caching
- ✅ Minimal JavaScript

## 🤝 Contributing

To contribute to the documentation:

1. Edit relevant README.md files in course sections
2. Test locally using `docsify serve`
3. Commit and push changes
4. GitHub Actions will auto-deploy

## 📚 Resources

- [Docsify Documentation](https://docsify.js.org/)
- [Docsify Themes](https://docsify.js.org/#/themes)
- [Docsify Plugins](https://docsify.js.org/#/plugins)
- [Markdown Guide](https://www.markdownguide.org/)

## 📧 Support

For issues or questions:
- 📧 Email: support@stacksimplify.com
- 🐙 GitHub Issues: [Create an issue](https://github.com/stacksimplify/devops-real-world-project-implementation-on-aws/issues)
- 💬 LinkedIn: [Kalyan Reddy Daida](https://www.linkedin.com/in/kalyan-reddy-daida/)

---

Made with ❤️ by [Stack Simplify](https://stacksimplify.com)
