# App Icon Setup

## Steps to Add Your App Icon:

1. **Create your icon image:**
   - Create a square PNG image (recommended: 1024x1024 pixels)
   - Name it `icon.png`
   - Place it in this directory (`assets/icon/icon.png`)

2. **Install the package:**
   ```bash
   flutter pub get
   ```

3. **Generate the icons:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **That's it!** The icons will be automatically generated for all platforms (Android, iOS, Web, Windows, macOS, Linux).

## Icon Requirements:

- **Format:** PNG
- **Size:** 1024x1024 pixels (recommended)
- **Background:** Transparent or solid color
- **Content:** Your app logo/icon should be centered

## Tips:

- Use a tool like [Canva](https://www.canva.com/) or [Figma](https://www.figma.com/) to create your icon
- Make sure your icon looks good on both light and dark backgrounds
- For Android adaptive icons, the foreground image should have padding (safe area) as the system may crop edges

