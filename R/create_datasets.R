#' Load selected NHANES files for a specific year
#'
#' @param f = nhanes file (no suffix -- just main file code like "mcq" and not "mcq_f" or "mcq_f.rds")
#' @param yr = first year of wave,
#' @param data_dir = The directory in which all of your NHANES subdirectories (one for each year) reside.  Default is the project "data" subdirectory (i.e., "./data") but if your data are elsewhere, you must specify the directory.  Keep in mind that this will be a directory that contains all of your NHANES subdirectories.  It is NOT the subdirectory for a specific year.  Do not use a slash (/) at the end.
#' @param lab = indicator of whether the label file should be included (if FALSE, then data file will be retrieved)
#' @return Returns a dataframe (a data.table) with the requested file.  This function can be used as a stand-alone function to get a single file, or it can be used with the load_merge function to do multiple files
#' @examples \dontrun{
#' Load single data files
#' demographics <- load_nhanes("demo", 2003)
#' med_cond_ques <- load_nhanes("mcq", 2009)
#'
#' # Load single label files
#' demographics_labels <- load_nhanes("demo", 2003, lab = TRUE)
#' med_cond_ques_labels <- load_nhanes("mcq", 2009, lab = TRUE)
#' }
#' @import data.table
#' @export
load_nhanes <- function(f = "", yr, data_dir = "./data", lab = FALSE){
    l <- letters[(yr - 1999) / 2 + 1]
    yr_yr <- paste(yr, yr + 1, sep = "_")
    ext <-
        if(lab == FALSE) {
            ".rds"
        } else {
            "_label.rds"
        }
    f1 <- paste0(data_dir, "/nhanes_", yr_yr, "/", f, "_", l, ext)
    f2 <- paste0(data_dir, "/nhanes_", yr_yr, "/", f, ext)
    if(file.exists(f1)) {
        o <- readRDS(f1)
    } else if(file.exists(f2)) {
        o <- readRDS(f2)
    } else {
        stop(paste0("can't find file called ", f, " - check name and start year to make sure it exists"))
    }
    setDT(o)
    if(lab == TRUE) {
        return(o[, list(name, label)])
    } else {
        return(o)
    }
}

#' Load and merge NHANES files
#'
#' Takes vector of NHANES file names, loads them, and merges them all by SEQN.  The function automatically loads the demo file, so you do not have to include "demo" in the character vector.  If you do include demo, or if you accidentally include the same filename twice, the function will only return a single copy of each file.
#'
#' @param vec_of_files A character vector of NHANES files (e.g., c("mcq", "biopro")) that identifies the stem of the desired file(s).  The demo file is ALWAYS included because it has the survey weights.  This vector should NOT include the final letter (e.g., _c) that indicates the wave (see yr).
#' @param yr The year for which the file should be extracted.
#' @param data_dir The directory in which all of your NHANES subdirectories (one for each year) reside.  Default is the project "data" subdirectory (i.e., "./data") but if your data are elsewhere, you must specify the directory.  Keep in mind that this will be a directory that contains all of your NHANES subdirectories.  It is NOT the subdirectory for a specific year.  Do not use a slash (/) at the end.
#' @return Returns a dataframe (which is also a data.table) with one column for each variable in each file requested.  Note that in some cases, there are multiple records per person (SEQN) in an NHANES file.  In this case, a list is returned with each item in the list being a dataframe with multiple records per person.  The prescription drug file (RXQ_RX) is an example.  All  files with one record per person are merged as usual, and returned as the first dataframe in the list.
#' @examples
#' nhanes_directory <- paste0(system.file(package = "nhanes.tools"), "/extdata") # location of data in package extdata directory
#' files_to_load <- c("mcq") # demo doesn't need to be included and will always be returned
#' full <- load_merge(files_to_load, 2009, nhanes_directory)
#' dim(full)
#' \dontrun{
#' # Example:  load many files listed in character vector
#' listing <- c("mcq", "dex", "hcq", "hiq", "vix", "uc") # demo is assumed
#' full <- load_merge(listing, 2003, "./data")
#' }
#' @export
load_merge <- function(vec_of_files = "demo", yr, data_dir = "./data") {
    if(any(vec_of_files == "demo" | vec_of_files == "")) {
        vec_of_files <- vec_of_files[vec_of_files != "demo" & vec_of_files != ""]
    }
    vec_of_files <- unique(vec_of_files)
    dt <- load_nhanes("demo", yr, data_dir)
    data.table::setkey(dt, SEQN)
    dt_list <- vector("list", length(vec_of_files))
    names(dt_list) <- vec_of_files
    for(f in vec_of_files){
        y <- load_nhanes(f, yr, data_dir)
        setkey(y, "SEQN")
        if(data.table::uniqueN(y) == nrow(y)){
            byvars <- intersect(names(dt), names(y))
            dt <- merge(dt, y, all.x = TRUE, by = byvars)
        } else {
            dt_list[[f]] <- y
        }
    }
    rem <- which(unlist(lapply(dt_list, is.null)))
    dt_list[rem] <- NULL
    if(!any(unlist(lapply(dt_list, is.null)))) {
        dt <- list(dt, dt_list)
        names(dt) <- c("cohort", names(dt_list))
    }
    return(dt)
}

#' Create data dictionary
#'
#' Creates a simple data dictionary based on variable labels for each NHANES file
#'
#' @param vec_of_files The character vector of files to be retrieved.  The "demo" file is ALWAYS included, and should NOT be specified.
#' @param yr The year for which the file should be extracted.
#' @param data_dir The directory in which all of your NHANES subdirectories (one for each year) reside.  Default is the project "data" subdirectory (i.e., "./data") but if your data are elsewhere, you must specify the directory.  Keep in mind that this will be a directory that contains all of your NHANES subdirectories.  It is NOT the subdirectory for a specific year.  Do not use a slash (/) at the end.
#' @return Returns a dataframe (a data.table) of all of the labels from each file in the character vector, including "demo".
#' @import data.table
#' @examples \dontrun{
#' # Load label files listed in character vector
#' full_labels <- load_labs_merge(listing, 2003)
#' }
#' @export
load_labs_merge <- function(vec_of_files = NULL, yr, data_dir = "./data") {
    vec_of_files <- c("demo", vec_of_files)
    vec_of_files <- unique(vec_of_files)
    dt <- lapply(vec_of_files, load_nhanes, yr = yr, lab = TRUE, data_dir = data_dir)
    dt1 <- data.table::rbindlist(dt)
    dt1 <- dt1[, list(name, label)]
    data.table::setkey(dt1, name)
    dt1 <- dt1[J(unique(name)), mult = "first"] # get rid of multiple SEQN rows
    return(dt1)
}
