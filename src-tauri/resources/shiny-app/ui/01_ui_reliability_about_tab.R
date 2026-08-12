# About panel for the test-retest reliability workflow
tabPanel(
  title = "Test-Retest Reliability",
  fluidRow(
    tags$div(
      class = "about-copy",
      tags$h3("Test-Retest Reliability Workflow"),
      tags$p(
        "This section implements the workflow from ",
        tags$a(
          href = "https://journals.sagepub.com/doi/10.1177/10422587231184071",
          "Test-Retest Reliability in Metric Conjoint Experiments: A New Workflow to Evaluate Confidence in Model Results",
          target = "_blank"
        ),
        ". The workflow is designed to help researchers evaluate response consistency for manipulated conjoint attributes before interpreting the substantive model results."
      ),
      tags$h4("Before You Load Data"),
      tags$ul(
        tags$li("Use CSV or one-sheet XLSX files only."),
        tags$li("Keep selected files below 5 MB."),
        tags$li("Reliability datasets must contain no more than 25,000 rows."),
        tags$li("Use long-format data with one row per respondent, round, and profile observation."),
        tags$li("Do not duplicate a respondent/round/profile combination."),
        tags$li("Use the bundled demo data if you want to inspect the required structure first.")
      ),
      tags$h4("Required Columns"),
      tags$ul(
        tags$li(tags$code("respondent"), " identifies the respondent."),
        tags$li(tags$code("round"), " identifies the initial round as 1 and the replication round as 2."),
        tags$li(tags$code("profile"), " identifies the conjoint profile."),
        tags$li(tags$code("dv"), " contains the dependent variable. Analyze one dependent variable at a time."),
        tags$li(tags$code("att_1"), ", ", tags$code("att_2"), ", ..., ", tags$code("att_x"), " contain the manipulated attributes. At least two attributes are required.")
      ),
      tags$p(
        tags$code("round"),
        ", ",
        tags$code("profile"),
        ", ",
        tags$code("dv"),
        ", and all ",
        tags$code("att_"),
        " columns must be numeric or cleanly coercible to numeric. Missing values should be left empty or coded as ",
        tags$code("NA"),
        "."
      ),
      tags$h4("Pairing And Completeness"),
      tags$ul(
        tags$li("Observations are paired by respondent and profile; their row order does not matter."),
        tags$li("Only profiles that occur in both rounds are analyzed. Profiles found in only one round are reported and excluded."),
        tags$li("A respondent who is missing any observation within the common profile set is excluded completely from both rounds."),
        tags$li("Validation requires at least two complete respondents and at least one computable common profile.")
      ),
      tags$h4("Workflow"),
      tags$ol(
        tags$li("Select your local CSV or XLSX file."),
        tags$li("Click the validate button to check the file structure."),
        tags$li("Inspect the table or variable types if needed."),
        tags$li("Run the analysis to compute the reliability results."),
        tags$li("Save the Excel workbook or CSV archive if you need local copies of the result tables."),
        tags$li("Use reset to clear the current selected file and generated session files.")
      ),
      tags$h4("What The Workflow Covers"),
      tags$ul(
        tags$li("Profile-level Pearson correlations."),
        tags$li("ICC(3,k) reliability estimates."),
        tags$li("Slope-difference checks between initial and replication rounds."),
        tags$li("A pooled regression model with clustered standard errors."),
        tags$li("Plots for response deviations, ICC summaries, and slope differences.")
      ),
      tags$p(
        "The workflow focuses on level-1 manipulated conjoint attributes and outcomes. Measured level-2 respondent variables are not part of this app's reliability workflow."
      )
    )
  )
)
