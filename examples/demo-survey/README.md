# NomadForms Demo Survey

A complete working example demonstrating NomadForms capabilities.

## 🚀 Quick Start

### Prerequisites

1. **R** (≥ 4.0): [Download R](https://cran.r-project.org/)
2. **Quarto** (≥ 1.3): [Download Quarto](https://quarto.org/docs/get-started/)
3. **R Packages**:

```r
install.packages(c("shiny", "DBI", "RPostgres", "jsonlite", "htmltools"))
```

### Run the Demo

```bash
# From the examples/demo-survey directory
quarto preview survey.qmd
```

The survey will open in your browser at `http://localhost:XXXX`

### Test on Mobile

1. Find your computer's local IP address:
   - **Mac/Linux**: `ifconfig | grep inet`
   - **Windows**: `ipconfig`

2. On your phone/tablet browser, go to:
   ```
   http://YOUR_IP_ADDRESS:PORT
   ```

## ✨ Features Demonstrated

### 📱 Mobile-First Design
- Touch-optimized controls (44px minimum touch targets)
- Responsive layout (works on phones, tablets, desktops)
- Large, readable fonts (no zoom needed on mobile)
- Swipe-friendly interface

### 🎨 Question Types
- ✅ Text input (name)
- ✅ Numeric input with validation (age 0-120)
- ✅ Radio buttons (gender, residence)
- ✅ Select dropdown (country)
- ✅ Slider (experience rating)
- ✅ Checkboxes (features - multiple selection)
- ✅ Text area (comments)

### ✓ Validation
- Required field checking
- Range validation (age)
- Real-time error messages
- Form-level validation before submit

### 🎯 User Experience
- Helpful text under questions
- Clear visual feedback
- Success/error notifications
- Clean, modern interface

## 📋 What Happens When You Submit

Currently (demo mode):
1. Validates all required fields
2. Shows success notification
3. Logs response to console
4. Generates session ID

**Next steps** (coming in Phase 2):
- Save to PostgreSQL database
- Offline storage with IndexedDB
- Background synchronization
- Export to Stata/SPSS/R

## 🧪 Testing Checklist

Try these on both desktop and mobile:

- [ ] Fill out all required fields and submit
- [ ] Try submitting without filling required fields (see validation)
- [ ] Test numeric input with invalid age (e.g., 150)
- [ ] Select multiple checkboxes
- [ ] Move the slider
- [ ] Resize browser window (test responsiveness)
- [ ] Test on actual mobile device

## 📱 Mobile Testing Tips

### iOS (Safari)
- Add to Home Screen for app-like experience
- Test in portrait and landscape

### Android (Chrome)
- Install as PWA (Add to Home Screen)
- Test with different keyboard types
- Check touch target sizes

## 🔧 Customization

### Change Styles

Edit `../../survey-runtime/inst/www/nomadforms.css`:
- Colors: Change CSS variables at top
- Spacing: Adjust padding/margin values
- Fonts: Update font-family

### Add Questions

Add to `survey.qmd`:

```r
::: {.form-group}
nf_question(
  "my_question",
  "text",
  "My Question Label",
  required = FALSE,
  help_text = "Optional help text"
)
:::
```

### Change Validation

Update in the server section:

```r
my_question = nf_validate(
  input$my_question, 
  required = TRUE, 
  type = "text"
)
```

## 🐛 Troubleshooting

### Survey won't load
- Check R and Quarto are installed: `quarto --version`
- Verify packages installed: `library(shiny)`
- Check for error messages in console

### Can't connect on mobile
- Ensure phone and computer on same WiFi network
- Check firewall isn't blocking the port
- Try using computer's IP address instead of localhost

### Validation not working
- Check browser console for JavaScript errors
- Verify R packages are loaded correctly
- Try clearing browser cache

## 📊 Console Output

When you submit, check your R console for:

```
=== Survey Response ===
$session_id
[1] "demo_20251101_120000"

$name
[1] "John Doe"

$age
[1] 25

... (rest of responses)
=====================
```

## 🎓 Next Steps

Once you've tested the demo:
1. Read the database setup guide (`database/README.md`)
2. Connect to a real PostgreSQL database
3. Uncomment the `nf_save_response()` code
4. Test data persistence
5. Try exporting data

## 💡 Tips for Your Own Surveys

1. **Keep it mobile-first**: Design for small screens first
2. **Use help text**: Guide users with hints
3. **Validate early**: Check inputs before submission
4. **Test on devices**: Real devices behave differently than emulators
5. **Optimize for speed**: Minimize question count per page

---

**Need help?** Open an issue on GitHub!

