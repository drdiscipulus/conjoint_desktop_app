# About panel for factorial design generation
tabPanel(
  title = "Factorial Designs",
  fluidRow(
    tags$div(
      class = "about-copy",
      tags$h3("Factorial Designs"),
      tags$p(
        "Factorial designs help researchers reduce the number of profiles shown in conjoint studies while preserving the information needed to estimate the intended effects. This app provides a graphical interface to established R tools for creating full and fractional designs."
      ),
      tags$h4("What The App Provides"),
      tags$ul(
        tags$li("A design table with generated profile combinations."),
        tags$li("For two-level designs, an interaction estimability table that shows which two-way interactions work separately and which are confounded."),
        tags$li("For N-level and mixed-level designs, an interaction coverage table that checks pairwise level-combination coverage and balance."),
        tags$li(
          "Access to design-generation functionality from ",
          tags$a(href = "https://cran.r-project.org/web/packages/FrF2/index.html", "FrF2", target = "_blank"),
          " and ",
          tags$a(href = "https://cran.r-project.org/web/packages/DoE.base/index.html", "DoE.base", target = "_blank"),
          "."
        )
      ),
      tags$h4("Two-Level Designs"),
      tags$ul(
        tags$li("Use this tab when all attributes have two levels, such as low/high or absent/present."),
        tags$li("Choose the number of attributes, then select a full or fractional design."),
        tags$li("For fractional designs, choose resolution III for main-effects-focused designs."),
        tags$li("Choose resolution IV when main effects should be clear from two-way interactions, but some two-way interactions may be confounded with each other."),
        tags$li("Choose resolution V when two-way interactions should be clear from main effects and from other two-way interactions, assuming higher-order interactions are negligible."),
        tags$li("Use the interaction estimability table before interpreting two-way interactions.")
      ),
      tags$h4("N-Level And Mixed-Level Designs"),
      tags$ul(
        tags$li("Use this tab when at least one attribute has more than two levels."),
        tags$li("Enter the number of levels for each attribute separated by commas, for example 4,4,4 or 2,4,4,3."),
        tags$li("The app currently supports up to 7 attributes and up to 4 levels per attribute."),
        tags$li("Full designs use all combinations. Fractional designs search mixed-level orthogonal arrays through DoE.base."),
        tags$li("For fractional designs, choose generalized Resolution III, IV, or V. Resolution IV keeps main effects clear from two-way interactions. Resolution V additionally keeps two-way interactions clear from one another, but usually requires more profiles."),
        tags$li("The app reports the full factorial size, the generated number of profiles, and whether a selected fractional design actually reduced the number of profiles."),
        tags$li("The interaction coverage table reports pairwise level-combination coverage and balance. It is not an aliasing or confounding diagnostic."),
        tags$li("The search for suitable fractional mixed-level designs can take time for some combinations, and some settings may still produce a full-factorial-sized design.")
      ),
      tags$h4("Method Notes"),
      tags$ul(
        tags$li("Full factorial designs are generated with fac.design()."),
        tags$li("Two-level fractional designs are generated with FrF2()."),
        tags$li("Mixed-level fractional designs use oa.design() and related orthogonal-array search utilities."),
        tags$li("Two-level designs use classical resolution. N-level and mixed-level orthogonal arrays use generalized resolution as implemented by DoE.base.")
      ),
      tags$h4("Further Reading"),
      tags$ul(
        tags$li(tags$a(href = "https://wires.onlinelibrary.wiley.com/doi/abs/10.1002/wics.27", "Gunst, R. F., & Mason, R. L. (2009). Fractional factorial design.", target = "_blank")),
        tags$li(tags$a(href = "https://www.itl.nist.gov/div898/handbook/pri/section3/pri333.htm", "NIST/SEMATECH e-Handbook of Statistical Methods", target = "_blank")),
        tags$li(tags$a(href = "https://en.wikipedia.org/wiki/Fractional_factorial_design", "Overview of fractional factorial designs and resolutions", target = "_blank"))
      ),
      tags$p(
        tags$strong("Important: "),
        "Always evaluate whether a generated design is suitable for your theoretical model before collecting data."
      )
    )
  )
)
