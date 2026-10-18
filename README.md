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



### Deployment
- Every push to `main` runs `.github/workflows/deploy-shinyapps.yml`: it runs `tests/smoke_test.R` against live AESO data, then deploys to shinyapps.io. It can also be run by hand from the Actions tab ("Run workflow").
- Requires repository secrets `SHINYAPPS_TOKEN` and `SHINYAPPS_SECRET` (shinyapps.io → Account → Tokens).
- Run the smoke test locally with `Rscript tests/smoke_test.R`.
