#' Print mean, SE, and CI nicely from survey functions
#'
#' Takes a survey object and prints out the results in a nicer format for a report.
#'
#' @param t A survey object from a svytotal, svymean, or svyby function
#' @param dig The number of digits to the right of the decimal (using formatC)
#' @return Returns a dataframe with character-formatted results summarizing the mean, standard error, and confidence interval
#' @examples \dontrun{
#' # nested syntax of base R:
#' out_tab(
#'    svytotal(~ variable_of_interest, survey_design_object, na.rm = TRUE)
#' )
#'
#' # can be used with magrittr syntax as well
#' svytotal(~ variable_of_interest, survey_design_object, na.rm = TRUE) %>%
#'    out_tab
#' }
#' @import survey
#' @export
output_table <- function(t, dig = 0) {
    x <- cbind(
            coef(t),
            SE(t),
            confint(t)
        )
    x <- as.data.frame(
            formatC(x, format = "f", big.mark = ",", digits = dig)
        )
    names(x) <- c("Total", "SE", "2.5%", "97.5%")
    return(x)
}

#' Generate NHANES design object
#'
#' Takes a data.frame with NHANES data and at least one weight variable, and creates the proper design object for it.  It simply puts the proper PSU strata, nest, and user-supplied weight into the svydesign function.  Note this does NOT set options(survey.lonely.psu = "adjust").
#'
#' @param df a data.frame or data.table created from NHANES data
#' @param wt The weight variable in the data as a character vector.  Common options include WTINT2YR, WTMEC2YR, and WTSA2YR.  See NHANES documentation for assigning weights across multiple years, and for choosing weights when there is more than 1 sampling frame (e.g., interview, mobile exam, fasting laboratory values, and other data subsets)
#' @return Returns a survey design object (which contains all of the data) for use in analyses
#' @examples \dontrun{
#' nhanes_design(df = df, wt = "WTINT2YR")
#' }
#' @import survey
#' @export
nhanes_design <- function(df, wt = "WTINT2YR") {
    x <- svydesign(id = ~ SDMVPSU, strata = ~ SDMVSTRA, nest = TRUE, weight = formula(paste0("~", wt)), data = df)
    return(x)
}
