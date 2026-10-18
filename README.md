# ALBERTA POWER GENERATION GRID

Link to the app: https://ohaley.shinyapps.io/ab_power/

### Application
- This application webscrapes the Alberta Electric System Operator websites for live electricity output data.
  - http://ets.aeso.ca/ets_web/ip/Market/Reports/CSDReportServlet

### Objective 
- Provide a more valuable way to intepret the raw data offered by AESO
- Provide traders, analysts and other professionals with visual insights into Alberta's power generation

#### Authors
Olivier Haley, Connor Beebe, Luke Talman & Brooklyn Holt



### Data
- `data/asset_planning_area.csv` maps each CSD asset to its AESO planning area (233 assets, from AESO's *CSD Generation (Hourly)* data, 2026-09).
- To refresh: download the latest monthly file from AESO's [Historical Generation Data (CSD)](https://www.aeso.ca/market/market-and-system-reporting/data-requests/historical-generation-data/), unzip, and run `Rscript data-raw/build_asset_lookup.R "path/to/CSD Generation (Hourly) - YYYY-MM.csv"`.
- The smoke test warns on the Actions run when a live asset has no planning area.

### Deployment
- Every push to `main` runs `.github/workflows/deploy-shinyapps.yml`: it runs `tests/smoke_test.R` against live AESO data, then deploys to shinyapps.io. It can also be run by hand from the Actions tab ("Run workflow").
- Requires repository secrets `SHINYAPPS_TOKEN` and `SHINYAPPS_SECRET` (shinyapps.io → Account → Tokens).
- Run the smoke test locally with `Rscript tests/smoke_test.R`.
