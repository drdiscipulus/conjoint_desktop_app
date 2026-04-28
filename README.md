# Conjoint Companion — Desktop Edition

A desktop application for conjoint analysis research. This is the offline companion to the [web version](https://shiny.drdiscipulus.de/conjoint_app/) and implements the methodology described in:

> **Developing a Test-Retest Reliability Coefficient for Metric Conjoint Analysis**  
> [Published in Organizational Research Methods (2023)](https://journals.sagepub.com/doi/abs/10.1177/10422587231184071)

## Overview

**Conjoint Companion** is a self-contained desktop application that bundles an R Shiny web interface with a complete R runtime. No installation of R, Python, or other dependencies is required—download and run.

This application is designed for researchers conducting conjoint studies and those needing to evaluate the reliability of their conjoint model results.

## Features

### 1. **Factorial Design Generator**

- Create full and fractional factorial designs for conjoint experiments
- Customize design parameters for your research needs
- Export designs for use in your studies

### 2. **Test-Retest Reliability Analysis**

- Upload your reliability study data (CSV or Excel format)
- Analyze the reliability of metric conjoint models
- Automatic processing and statistical evaluation
- Export results in multiple formats (XLSX, CSV, visualizations)

### 3. **Fully Offline**

- All processing happens locally on your computer
- No internet connection required after installation
- All data remains on your machine
- Session-based temporary files are automatically cleaned up

## Installation

### System Requirements

- **Windows 10+** (x64) or **macOS 11+** (Apple Silicon or Intel)
- **Disk space:** ~500 MB
- **RAM:** 2 GB minimum (4 GB recommended)

### Download & Run

1. Download the latest release for your platform:
   - **Windows:** `Conjoint Companion-win-x64.zip` → Extract and run `Conjoint Companion.exe`
   - **macOS:** `Conjoint Companion.app.tar.gz` → Extract and drag to Applications, then run

2. Launch the application—no installation wizard, no system modifications

3. Read the in-app help and tutorial to get started

## Quick Start

### Factorial Design Generator

1. Open the application and navigate to **Design Generator**
2. Select your design parameters (factors, levels, type of design)
3. Click **Generate** and review the design
4. Download the design as CSV or Excel

### Reliability Analysis

1. Prepare your data in CSV or Excel format with columns:
   - `respondent`: Participant ID
   - `round`: Test (1) or retest (2) administration
   - `profile`: Profile ID within the conjoint study
   - `dv`: Dependent variable (conjoint preference rating)
   - `att_*`: Attribute columns (attribute values for the profile)

2. Open the application and navigate to **Reliability Analysis**
3. Upload your data file
4. View analysis results and download the report

**Demo data:** Sample files are available in the application for testing

## Data Privacy & Security

- **Local processing:** All uploaded data is processed on your computer only
- **Session-based storage:** Data is stored in temporary directories that are automatically deleted when you close the application
- **No tracking:** The application does not collect usage data or contact external servers
- **Offline operation:** Internet connection is never required for analysis

## System Architecture

This is a **Tauri desktop application** combining:

- **Tauri 2** framework (Rust backend, web frontend)
- **R Shiny** web interface for interactive analysis
- **R 4.5.3** runtime (bundled)
- **renv** for R package management

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical details.

## Troubleshooting

### App won't start

- **Windows:** Ensure you have extracted the ZIP file completely. Windows sometimes has issues running apps from within ZIP archives.
- **macOS:** If you see a security warning, right-click the app and select "Open" to bypass it on first launch.

### Data upload fails

- Check that your CSV/Excel file has the required columns: `respondent`, `round`, `profile`, `dv`, and attribute columns (`att_*`)
- Ensure column names exactly match (case-sensitive)
- Max file size: 50 MB

### Performance issues

- Close other applications to free up memory
- Ensure you have at least 2 GB of available RAM
- Restart the application

### More help

- See the **Help** section within the application
- Review the tutorial and demo data
- Check the published paper for methodology details

## Related Resources

- **Web version:** [https://shiny.drdiscipulus.de/conjoint_app/](https://shiny.drdiscipulus.de/conjoint_app/)
- **Published paper:** [https://journals.sagepub.com/doi/abs/10.1177/10422587231184071](https://journals.sagepub.com/doi/abs/10.1177/10422587231184071)
- **Source code:** This GitHub repository

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0).  
See [LICENSE](LICENSE) for details.

## FAQ

**Q: Is this the same as the web version?**  
A: It's the same analysis tools with the same methodology, but the desktop version runs entirely offline without needing any server.

**Q: Can I use my data from the web version in the desktop version?**  
A: Yes—data formats are identical. Export from the web version and upload to the desktop version.

**Q: Do I need to install R?**  
A: No. R is bundled with the desktop application.

**Q: What happens to my data when I close the app?**  
A: All temporary data is automatically deleted. Only files you explicitly download are saved.

**Q: Can I run this on Linux?**  
A: Not currently. The desktop app is available for Windows and macOS only.

**Q: Is this open source?**  
A: Yes, the source code is available under GPL-3.0. See the GitHub repository.

---

**Questions or issues?** Open an issue on GitHub or review the in-app Help section.
