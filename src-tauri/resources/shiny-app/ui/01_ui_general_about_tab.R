# Overview tab for the app purpose, scope, and data handling
tabPanel(
  title = "Overview",
  fluidRow(
    tags$div(
      class = "about-copy",
      tags$h3("Conjoint Companion"),
      tags$p(
        "This app accompanies the workflow introduced in ",
        tags$a(
          href = "https://journals.sagepub.com/doi/10.1177/10422587231184071",
          "Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow to Evaluate Confidence in Model Results",
          target = "_blank"
        ),
        ". It helps researchers prepare conjoint designs and evaluate response consistency in metric conjoint experiments."
      ),
      tags$h4("What You Can Do"),
      tags$ul(
        tags$li("Generate full and fractional factorial designs for conjoint studies."),
        tags$li("Inspect two-way interaction estimability for two-level fractional designs."),
        tags$li("Inspect pairwise coverage and balance for N-level and mixed-level designs."),
        tags$li("Load conjoint response data from a local CSV or XLSX file and run the test-retest reliability workflow from the paper."),
        tags$li("Review reliability tables, regression diagnostics, and plots."),
        tags$li("Save sample data, generated designs, and analysis results locally.")
      ),
      tags$h4("How To Use The App"),
      tags$ol(
        tags$li("Use the factorial design tabs if you still need to construct a conjoint design."),
        tags$li("Use the test-retest reliability tab when you have data from an initial and replication round."),
        tags$li("Start with the bundled demo data if you want to inspect the required structure first."),
        tags$li("Validate your selected local data file before running the analysis.")
      ),
      tags$h4("Data Handling"),
      tags$p(
        "The desktop app runs on your computer. When you choose a CSV or one-sheet XLSX file, it is read by the local R/Shiny process that is started by the desktop app. The file is not uploaded to a remote server. The app applies a 5 MB file limit and rejects reliability datasets with more than 25,000 rows. Temporary working files are kept in a session-specific local folder and removed when the session ends."
      ),
      tags$h4("Privacy"),
      tags$p(
        "Your research data stays on your computer. The app does not send selected files, generated designs, analysis results, or usage behavior to the authors, the university, or any external service. Files you save with the app are written next to the application executable. Reset clears the current local session state; closing the app also removes the session-specific temporary files."
      ),
      tags$h4("Paper, Data, And Authors"),
      tags$ul(
        tags$li("Paper: ", tags$a(href = "https://journals.sagepub.com/doi/10.1177/10422587231184071", "Entrepreneurship Theory and Practice article", target = "_blank")),
        tags$li("Open Science Framework: ", tags$a(href = "https://osf.io/qpzhf/?view_only=61cd1571ec23440da1974756002a819e", "publication code and data", target = "_blank")),
        tags$li("Jens Schüler: ", tags$a(href = "https://www.eship.uni-bayreuth.de/de/team/schueler_jens/index.php", "profile page", target = "_blank")),
        tags$li("Brian S. Anderson: ", tags$a(href = "https://business.ku.edu/people/brian-anderson", "profile page", target = "_blank")),
        tags$li("Charles Y. Murnieks: ", tags$a(href = "https://bloch.umkc.edu/profiles/faculty-directory/charles-y.-murnieks.html", "profile page", target = "_blank")),
        tags$li("Matthias Baum: ", tags$a(href = "https://www.eship.uni-bayreuth.de/de/team/baum_matthias/index.php", "profile page", target = "_blank")),
        tags$li("Alexander Küsshauer: ", tags$a(href = "https://www.linkedin.com/in/alexkuesshauer/?originalSubdomain=de", "profile page", target = "_blank"))
      ),
      tags$p(
        "Please review your results carefully. This app supports the workflow described in the paper, but it does not replace substantive judgment about your conjoint design, measurement strategy, or model specification."
      ),
      tags$p("R Shiny app written by Jens Schüler.")
    )
  )
)
