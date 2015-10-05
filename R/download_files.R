#' Set up directories
#'
#' This function sets up the directories and subdirectories on your computer for subsequent downloading by other functions.
#' This is the basic setup piece to facilitate the entire download and extraction process.  The returned object governs the rest of the process.
#'
#' @param data_dir This is directory on computer in which subdirectories will be made for all nhanes files (can end in "/" on Mac but CANNOT on Windows).  This will be created as a temporary directory if it doesn't exist.  Use data_dir = "." to use the current working directory.
#' @param yr This is the first year of the NHANES wave of interest (always odd, starting in 1999 and ending in 2011)
#' @return A list is returned with 4 items:  the url to download data from, the url to download death data from, the target directory into which subdirectories should be placed for the NHANES wave, and the years of the wave to be downloaded.
#' @examples \dontrun{
#' # Basic example of function
#' n <- setup_nhanes(data_dir = "./data", yr = 2011)
#' }
#'
#' \dontrun{
#' # Example of entire workflow
#' # Get entire NHANES directory and read into subdirectory as .rds objects
#' # Note:  may work better doing this one or two waves at a time
#' # Can use waves[1:7] in outer for loop to choose waves to load
#' # Similarly can use filenames[1:20] in inner for loop to choose filenames to load
#' waves <- seq(1999, 2011, 2)
#' for(wave in waves){
#'     message("Starting wave: ", wave)
#'     n <- setup_nhanes(data_dir = "./data", yr = wave)
#'     filenames <- get_nhanes_filenames(n)
#'     for(file in filenames) {
#'         download_nhanes(file, n)
#'     }
#'     message("Finished wave: ", wave)
#' }
#'
#' # Example of parallel download process
#' # Not quite twice as fast (on my computer)
#' # Returns a list of completed files at the end.  Set console = FALSE in above functions.
#' # Need to use foreach syntax for nested loops to redo above in completely parallel fashion
#' library(foreach)
#' library(doMC) # use library(doSNOW) on Windows
#' registerDoMC(cores = 4) # set number of cores for your computer
#' foreach(file = filenames, .packages = c("foreign", "downloader"), .combine = rbind) %dopar% {
#'     download_nhanes(file, n, console = FALSE)
#' }
#' }
#' @export
setup_nhanes <- function(data_dir = NULL, yr = 2011){
    if(is.null(data_dir)) {
        data_dir <- tempdir()
    }
    if(!file.exists(data_dir)) stop("The data_dir you provided does not exist or the syntax is wrong.  On Unix/Mac you can use a slash at the end, but on Windows you cannot use the slash.")
    data_dir <- normalizePath(path.expand(data_dir), winslash = "/")
    if(!yr %in% seq(1999, 2011, 2)) stop("first year must be an odd number from 1999 to 2011")
    data_url <- paste0("ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/nhanes/", yr, "-", yr + 1, "/") # ftp location of data files
    death_url <- paste0("ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/linked_mortality/") # ftp location of death files
    diryears <- paste(yr, yr + 1, sep = "_")
    target_dir <- paste0(data_dir, "/nhanes_", diryears, "/") # name of subdirectory where downloaded data will be saved
    dir.create(target_dir, showWarnings = FALSE) # suppress warning if directory already exists
    output <- list(data_url = data_url, death_url = death_url, target_dir = target_dir, years = diryears)
    return(output) # returns needed data elements for later functions
}

#' Get filenames from FTP server
#'
#' Returns filenames from ftp directory as well as details about files.
#' Intended to be work behind the scenes (hidden). getURL syntax taken from RCurl package example
#'
#' @param dir_url A specific URL to be downloaded created by running setup_nhanes()
#' @param select A character string to select a subset of filenames (e.g., ".dat", ."xpt")
#' @return A dataframe of filenames and details (e.g., size, date, filename)
#' @export
.get_filenames <- function(dir_url, select = "") {
    f <- RCurl::getURL( dir_url, ftp.use.epsv = FALSE, crlf = TRUE)
    f <- unlist(strsplit(f, "\r*\n"))
    f <- grep(select, f, ignore.case = TRUE, value = TRUE)
    if(length(f) == 0) {
        f <- NULL
        return(f)
    } else {
        f <- strsplit(f, "\\s+")
        f <- as.data.frame(do.call(rbind, f))
        f <- f[, 5:9]
        names(f) <- c("size", "month", "day", "year", "filename")
        return(f)
    }
}

#' Get NHANES filenames
#'
#' Gets all relevant NHANES filenames for a given year, both for the main data and for the mortality files
#'
#' @param setup The object (list) returned from the "setup_nhanes" function
#' @param save_file_list Indicates whether the directory contents should be saved as a separate file (called "download_file_specs.rds")
#' @return A character vector of ftp urls ("filenames") to download
#' @examples \dontrun{
#' # Requires that setup_nhanes has been run and its result assigned to object "n"
#' n <- setup_nhanes(data_dir = "./data", yr = 2011)
#' filenames <- get_nhanes_filenames(setup = n)
#' }
#' @export
get_nhanes_filenames <- function(setup, save_file_list = TRUE){
    f_data <-  .get_filenames(setup$data_url, select = ".xpt$")
    f_death <- .get_filenames(setup$death_url, select = paste0("NHANES_", setup$years))
    if(save_file_list){
        f1 <- rbind(f_data, f_death)
        saveRDS(f1, paste0(setup$target_dir, "download_file_specs.rds"))
    }
    filenames_data <-
        paste0(setup$data_url, f_data$filename)
    filenames_death <-
        if(length(f_death) == 0) {
            NULL
        } else {
            paste0(setup$death_url, f_death$filename)
        }
    filenames <-
        c(filenames_data, filenames_death)
    return(filenames)
}

#' Download xpt and convert to rds
#'
#' Takes a URL for a specific file on the NHANES ftp site, downloads to temp file, converts from SAS transport to R, and saves data and labels as an RDS file in destination directory.  Intended to be a hidden function.
#'
#' @param ftp_url A specific URL to be downloaded via FTP and converted to an R dataframe
#' @param setup The list object from running nhanes_setup with the details needed for naming and saving the files
#' @param console Set to FALSE to skip messages for download progress.  Useful when running parallel.  When FALSE, invisibly returns the status of the download, which is reported by the foreach package
#' @export
.read_save_xpt <- function(ftp_url, setup, console = TRUE, ...) {
    op <- options(stringsAsFactors = FALSE)
    on.exit(options(op))
    if(console) {
        message("Loading wave = ", setup$years, ", file = ", basename(ftp_url), appendLF = FALSE)
    }
    temp <- tempfile()
    .try_download(ftp_url, temp, mode = "wb", quiet = TRUE, ...) # "curl" MUCH faster than "auto"
    f <- foreign::read.xport(temp) # extracts data file(s)
    l <- foreign::lookup.xport(temp) # extracts format information list (may have more than 1 item)
    orig_name <- paste0(tolower(names(l)), ".rds")
    orig_name_label <- gsub(".rds", "_label.rds", orig_name) # name formats file
    finalname <- paste0(setup$target_dir, orig_name) # full name with path included
    finalname_label <- paste0(setup$target_dir, orig_name_label) # full name with path included
    names(l) <- NULL # removes file name from format list which removes it from variable names when converted to data.frame below
    l <- lapply(l, data.frame) # makes format list a list of dataframes (recycles some vectors like length, headpad, etc)
    names(l) <- orig_name_label
    lapply(1:length(finalname_label), function(i) saveRDS(l[[i]], finalname_label[[i]])) # formats saved using RDS (compressed binary file)
    if(class(f) == "data.frame"){ # determines whether there is a single dataframe or a list of dataframes to save
        saveRDS(f, finalname) # save single file using RDS
    } else {
        lapply(1:length(finalname),   function(i) saveRDS(f[[i]], finalname[[i]])) # data a list of dataframes using RDS for each
    }
    if(console) {
        message("Completed. File count: ", length(finalname))
    } else {
        r <- paste0("Completed:  ", basename(ftp_url), "File count:  ", length(finalname))
        return(r)
    }
}

#' Download mortality file
#'
#' Function to download associated death file for specific NHANES year
#' Set console to false if running parallel
#' @param ftp_url A specific URL to be downloaded via FTP and converted to an R dataframe
#' @param setup The list object from running nhanes_setup with the details needed for naming and saving the files
#' @param console Set to FALSE to skip messages for download progress.  Useful when running parallel.  When FALSE, invisibly returns the status of the download, which is later reported by the foreach package after all downloads have completed
#' @export
.read_save_fwf <- function(ftp_url, setup, console = TRUE, ...){
    op <- options(stringsAsFactors = FALSE)
    on.exit(options(op))
    if(console){
        message("Loading wave = ", setup$years, ", death file = ", basename(ftp_url), appendLF = FALSE)
    }
    s <- .create_death_specs()
    temp <- tempfile()
    .try_download(ftp_url, temp, quiet = TRUE, ...)
    dat <- readr::read_fwf(temp, readr::fwf_positions(s$fwf$start, s$fwf$end, col_names = s$fwf$var), col_types = paste0(s$fwf$type, collapse = ""), na = ".")
    filename_data <- paste0(setup$target_dir, "death.rds")
    filename_labs <- paste0(setup$target_dir, "death_label.rds")
    saveRDS(dat, filename_data)
    saveRDS(s$labs, filename_labs)
    if(console) {
        message("Completed loading death file.\n")
    } else {
        r <- paste0("Completed:  ", basename(filename_data))
        return(r)
    }
}

#' Download files
#'
#' Handles errors and warnings in the download process
#' Source:  http://stackoverflow.com/questions/12193779/how-to-write-trycatch-in-r
#' @param link
#' @param dest
#' @param times
#' @param warn_msg
#' @param err_msg
#' @param fin_msg
#' @param ... Used to pass options to download function (which wraps download.file())
#' @export
.try_download <- function(link, dest, times = 5, warn_msg = "There was a warning!", err_msg = "There was an error!", fin_msg = NULL, ...){
    check <- 1
    while(check <= times & check > 0) {
        check <- check +
            tryCatch(
            {
                downloader::download(link, dest, ...)
                return(-check)
            },
            warning = function(cond) {
                if(!is.null(warn_msg)){
                    message(warn_msg)
                    message(cond)
                    message("\nAttempt = ", check)
                }
                return(1)
            },
            error = function(cond) {
                if(!is.null(err_msg)){
                    message(err_msg)
                    message(cond)
                    message("\nAttempt = ", check)
                }
                return(1)
            },
            finally = {
                message(fin_msg)
            })
    }
    invisible(check - 1)
}

#' Download NHANES files
#'
#' This function selects the proper download function to use for each type of file, data and mortality.
#'
#' @param ftp_url A specific URL to be downloaded via FTP and converted to an R dataframe
#' @param setup The list object from running nhanes_setup with the details needed for naming and saving the files
#' @param ... To pass options to the download function (which wraps download.file()).  Also can set console = FALSE to skip messages for download progress, which is useful when running parallel.  When FALSE, invisibly returns the status of the download, which is later reported by the foreach package after all downloads have completed.
#' @examples \dontrun{
#' # Example of basic download using a loop across all of the ftp download URLs.
#' # In this example, n is the object created by the function setup_nhanes() and
#' # filenames is created from teh function get_nhanes_filenames()
#'     for(file in filenames){
#'         download_nhanes(file, n)
#'     }
#' # Example of parallel download process
#' # Not quite twice as fast (on my computer)
#' # Returns a list of completed files at the end.  Set console = FALSE in above functions.
#' # Need to use foreach syntax for nested loops to redo above in completely parallel fashion (not shown)
#' library(foreach)
#' library(doMC) # use library(doSNOW) on Windows
#' registerDoMC(cores = 4) # set number of cores for your computer
#' foreach(file = filenames, .packages = c("foreign", "downloader"), .combine = rbind) %dopar% {
#'     download_nhanes(file, n, console = FALSE)
#' }
#' }
#' @export
download_nhanes <- function(ftp_url, setup, ...){
    if(grepl(".xpt$", ftp_url, ignore.case = TRUE)){
        .read_save_xpt(ftp_url, setup, ...)
    } else if(grepl(".dat$", ftp_url, ignore.case = TRUE)){
        .read_save_fwf(ftp_url, setup, ...)
    } else {
        stop("file to be downloaded does not end in .xpt or .dat")
    }
}

#' Create mortality file specs
#'
#' Creates information for loading mortality data and variable labels
#' This is intended to be a hidden function.
#'
#' @param There are no inputs to this.
#' @return Returns a dataframe with specifications for reading in the fixed-width mortality file using readr package
#' @examples
#' df <- .create_death_specs()
#' @export
.create_death_specs <- function() {
    list(
        fwf =
            rbind(
                data.frame(var = "SEQN",          start =  1, end =  5, type = "i"),
                data.frame(var = "ELIGSTAT",      start = 15, end = 15, type = "i"),
                data.frame(var = "MORTSTAT",      start = 16, end = 16, type = "i"),
                data.frame(var = "CAUSEAVL",      start = 17, end = 17, type = "i"),
                data.frame(var = "UCOD_LEADING",  start = 18, end = 20, type = "c"),
                data.frame(var = "DIABETES",      start = 21, end = 21, type = "i"),
                data.frame(var = "HYPERTEN",      start = 22, end = 22, type = "i"),
                data.frame(var = "PERMTH_INT",    start = 44, end = 46, type = "i"),
                data.frame(var = "PERMTH_EXM",    start = 47, end = 49, type = "i"),
                data.frame(var = "MORTSRCE_NDI",  start = 50, end = 50, type = "i"),
                data.frame(var = "MORTSRCE_CMS",  start = 51, end = 51, type = "i"),
                data.frame(var = "MORTSRCE_SSA",  start = 52, end = 52, type = "i"),
                data.frame(var = "MORTSRCE_DC",   start = 53, end = 53, type = "i"),
                data.frame(var = "MORTSRCE_DCL",  start = 54, end = 54, type = "i")
            ),
        labs =
            rbind(
            	data.frame(name = "SEQN",          label =	'NHANES Respondent Sequence Number'),
            	data.frame(name = "ELIGSTAT",      label =	'Eligibility Status for Mortality Follow-up'),
            	data.frame(name = "MORTSTAT",      label =	'Final Mortality Status'),
            	data.frame(name = "CAUSEAVL",      label =	'Cause of Death Data Available'),
            	data.frame(name = "UCOD_LEADING",  label =	'Underlying Cause of Death Recode from UCOD_113 Leading Causes'),
            	data.frame(name = "DIABETES",      label =	'Diabetes flag from multiple cause of death'),
            	data.frame(name = "HYPERTEN",      label =	'Hypertension flag from multiple cause of death'),
            	data.frame(name = "PERMTH_INT",    label =	'Person Months of Follow-up from Interview Date'),
            	data.frame(name = "PERMTH_EXM",    label =	'Person Months of Follow-up from MEC/Exam Date'),
            	data.frame(name = "MORTSRCE_NDI",  label =	'Mortality Source: NDI Match'),
            	data.frame(name = "MORTSRCE_CMS",  label =	'Mortality Source: CMS Information'),
            	data.frame(name = "MORTSRCE_SSA",  label =	'Mortality Source: SSA Information'),
            	data.frame(name = "MORTSRCE_DC",   label =	'Mortality Source: Death Certificate Match'),
            	data.frame(name = "MORTSRCE_DCL",  label =	'Mortality Source: Data Collection')
            )
    )
}

#' Generate a list of all downloadable NHANES files
#'
#' Generates a list of downloadable NHANES data files from the CDC website, as well as the meta-data about the files.  This is primarily used to populate the internal table in the package.  However, this function is accessible so you can compare the most current version to the internal list within the package to see if anything has changed.  Note that changes to the NHANES website might make this function fail.
#'
#' @return A dataframe with a list of all of the available NHANES files.
#' @export
get_nhanes_listing <- function(){
    nhanes_url <- "http://wwwn.cdc.gov/Nchs/Nhanes/Search/DataPage.aspx"
    tbl <- xml2::read_html(nhanes_url)

    table_text <- rvest::html_table(tbl)
    table_text <- data.frame(table_text, stringsAsFactors = FALSE) # just gets table, not hyperlinks in table
    names(table_text) <- gsub("\\.", "_", names(table_text))
    names(table_text) <- tolower(names(table_text))
    table_text <- table_text[table_text$data_file != "RDC Only",]
    table_text$key <- gsub(" Doc", "", table_text$doc_file)
    table_text$key <- tolower(table_text$key)

    cell_urls <- rvest::html_nodes(tbl, "#PageContents_GridView1 a")
    cell_urls <- rvest::html_attr(cell_urls, "href")

    documentation <- cell_urls[grepl("htm$", cell_urls)]
    documentation <- data.frame(doc_link = documentation, stringsAsFactors = FALSE)
    documentation$key <- gsub(".htm", "", basename(documentation$doc_link))
    documentation$key <- tolower(documentation$key)

    download_url <- cell_urls[grepl("(XPT|xpt)$", cell_urls)]
    download_url <- data.frame(data_link = download_url, stringsAsFactors = FALSE)
    download_url$key <- gsub("(.XPT|.xpt)", "", basename(download_url$data_link))
    download_url$key <- tolower(download_url$key)

    url_list <- merge(download_url, documentation, all.x = TRUE)
    nhanes_file <- merge(table_text, url_list)

    nhanes_file$name <- gsub("_[a-z]{1}$", "", nhanes_file$key)
    year_list <- strsplit(nhanes_file$years, "-")
    nhanes_file$start_yr <- do.call(rbind, lapply(year_list, function(x) x[[1]]))
    nhanes_file$end_yr <- do.call(rbind, lapply(year_list, function(x) x[[2]]))
    nhanes_file$wave <- ifelse(as.numeric(nhanes_file$end_yr) - as.numeric(nhanes_file$start_yr) > 1, "multiple", nhanes_file$start_yr)
    return(nhanes_file)
}
