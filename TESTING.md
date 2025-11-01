# 🧪 Testing NomadForms Locally

Quick guide to test the current features on your machine and mobile devices.

## ⚡ Quick Test (5 minutes)

### 1. Install Prerequisites

**Check if you have them:**
```bash
R --version          # Should be >= 4.0
quarto --version     # Should be >= 1.3
```

**Don't have them?**
- **R**: https://cran.r-project.org/
- **Quarto**: https://quarto.org/docs/get-started/

### 2. Install R Packages

```r
# Open R console and run:
install.packages(c("shiny", "DBI", "RPostgres", "jsonlite", "htmltools"))
```

### 3. Run the Demo

```bash
cd examples/demo-survey
quarto preview survey.qmd
```

**✅ Success**: Browser opens automatically showing the survey!

## 📱 Test on Your Phone/Tablet

### Step 1: Find Your Computer's IP

**Mac/Linux:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**Windows:**
```cmd
ipconfig
```

Look for something like `192.168.1.100`

### Step 2: Note the Port

When you run `quarto preview`, you'll see:
```
Browse at http://localhost:5432
```

The number after the colon (5432) is your port.

### Step 3: Connect from Mobile

On your phone/tablet, open browser and go to:
```
http://YOUR_IP_ADDRESS:YOUR_PORT
```

Example: `http://192.168.1.100:5432`

**💡 Tip**: Make sure your phone and computer are on the same WiFi network!

## ✨ What to Test

### Desktop Browser
- [ ] Fill out all fields
- [ ] Try submitting without required fields (should show errors)
- [ ] Enter age > 120 (should show validation error)
- [ ] Select multiple checkboxes
- [ ] Move the slider
- [ ] Resize browser window (test responsiveness)
- [ ] Submit successfully and check console

### Mobile Device
- [ ] All questions are readable without zooming
- [ ] Touch targets are easy to tap (not too small)
- [ ] Keyboard appears correctly for different field types
- [ ] Radio buttons and checkboxes are easy to select
- [ ] Slider works with touch
- [ ] Submit button is easily tappable
- [ ] Success notification appears

### Both
- [ ] Form looks good in portrait mode
- [ ] Form looks good in landscape mode
- [ ] Required field indicators (* in red) show
- [ ] Help text appears under questions
- [ ] Validation errors are clear

## 🎯 Expected Results

### When You Submit Successfully:

**Browser**: Green notification saying "Success! Survey submitted successfully!"

**Console** (R terminal): You should see:
```
=== Survey Response ===
$session_id
[1] "demo_20251101_143052"

$name
[1] "Test User"

$age
[1] 25
...
=====================
```

### When Validation Fails:

**Browser**: Red notification listing the problems

**Console**: No output (form didn't submit)

## 🐛 Common Issues

### "Quarto not found"
**Solution**: Install Quarto from https://quarto.org/docs/get-started/

### "Package 'shiny' not found"
**Solution**: Run `install.packages("shiny")` in R

### Can't connect from mobile
**Solutions**:
1. Check both devices on same WiFi
2. Check firewall settings
3. Try your computer's alternate IP address
4. Restart quarto preview

### Survey loads but looks broken
**Solution**: Clear browser cache and reload

## 📊 Current Features (Phase 1)

✅ **Implemented**:
- 7 question types (text, numeric, radio, checkbox, select, slider, textarea)
- Mobile-responsive design
- Touch-optimized controls
- Field validation
- Success/error notifications
- Session tracking

⏸️ **Coming Next**:
- Database persistence
- Offline capability
- Visual survey builder
- Data export

## 🚀 Next Test Session

After I implement database integration (next commit), you'll be able to test:
- Saving responses to PostgreSQL
- Viewing saved data
- Basic data export

**Want to test sooner?** Let me know and I'll prioritize specific features!

---

**Happy Testing!** 🎉

Report issues: https://github.com/gondamol/nomadforms/issues

