# nhanes.tools
R package to make loading and using NHANES data easier

This package includes functions to download [NHANES](http://www.cdc.gov/nchs/nhanes/about_nhanes.htm) files from 1999 and later, and store them as .rds files in a data directory on the user's computer.  There are also some simple utilities to merge selected files into useable dataframes using the data.table package.  

The functions in this package will download NHANES data from the CDC's ftp server, including the mortality files.  It was tested on a Mac running Yosemite, R 3.1.3, and RStudio 0.99.447.  I also tested it on Windows 7 via VMware Fusion, R 3.2.1, and RStudio 0.99.467.  It seems to work on both platforms.  However, we did run into an issue with Kaspersky anti-virus on Windows 7 blocking `download.file()`, so if you can't download, try pausing your antivirus/firewall software.  There is/was a challenge in properly identifying subdirectories into which the files would be written because Windows doesn't want a trailing slash (/), and Mac likes one.  But if you **do not use** the trailing slash on either platform, all *should* be well.  

The ftp download sometimes crashes (due to the FTP server, not the code as far as I know).  If that happens, you have to delete the entire wave that was in the process of being downloaded and restart.  Or, if you notice where it failed, you can download from the failure point.  I added "try-catch" functionality to retry downloading and address this possibility, but I have not found a good way to test this to see how well it works.  By the way, thanks to the [downloader package](https://github.com/wch/downloader) for sorting the downloading issues on Windows.  And thanks to [ROpenSci](https://ropensci.org) for some [suggestions](https://discuss.ropensci.org/t/data-only-packages/203/4) and code on downloading from FTP sites.

Single waves take 5-10 minutes each on my computer to download and resave as .rds files, which are compressed by default.  Across all waves the data occupy about 250 MB (compressed size) on my hard drive.  I have also included code to do the download in parallel, which, on my 4-core machine gives a little less than a 2-fold speed up.  I also added some progress messages. 

The process also saves a file that lists all the files in the FTP directory.  This listing, and the download process itself, only works on .xpt files and a fixed-width file (.dat) for the mortality data.  There are some .txt files in the ftp directories that are ignored.  

There are also some functions to load the data into your workspace and to merge multiple files for an analysis into a single file (merged by SEQN).  Note that the utilities to merge the files use [data.table](https://github.com/Rdatatable/data.table), but the process could be done with base::merge or [dplyr](https://github.com/hadley/dplyr).  We use data.table for most everything, because it is really fast and has nice utilities like rbindlist() for combining datasets (a fast, simple version of do.call(rbind, list)).

In the future, I will be adding an "nhanes" class to each file, as well as some attributes for the labels, and developing some tools to facilitate common analyses.

## To Install and Use
Install using devtools. Make sure Rcpp is installed.  (On Windows, you also need to install Rtools.)

```R
library(devtools)
install_github(repo = "outcomesinsights/nhanes.tools")
library(nhanes.tools)
```
Below is some sample code for downloading the entire NHANES data.  The "[1:7]" is optional, but shows how you might download just a few waves.

```R
waves <- seq(1999, 2011, 2) # for looping.  2013-2014 is not available yet 
for(wave in waves[1:7]){
    message("Starting wave: ", wave)
    n <- setup_nhanes(data_dir = "./data/raw", yr = wave)
    filenames <- get_nhanes_filenames(n)
    for(file in filenames){
        download_nhanes(file, n)
    }
    message("Finished wave: ", wave)
}
```

Below is a way to do a single year using parallel downloading.  To do all waves in parallel, you need to use the foreach nested loop syntax.  The code below uses "filenames[1:5]" which will download the first 5 files.  Just use "filenames" to download all files in the wave.
```R
library(foreach)
library(doMC)

registerDoMC(cores = 4)
foreach(file = filenames[1:5], .packages = c("foreign", "downloader"), .combine = rbind) %dopar% {
    download_nhanes(file, n, console = FALSE)
}
```
This shows how to download a subset of files.  You have to create the character vector "filenames" first, as shown above.  For 1999, this will download the last 7 files, plus the mortality file.
```R
for(file in filenames[110:117]){
        download_nhanes(file, n)
    }
```

This is some code to compare parallel vs. serial downloading using the first 24 files of a given year.
```R
# compare parallel vs serial downloading (serial ~ 1.75x parallel download time)
library(rbenchmark)
benchmark(
    foreach(file = filenames[1:24], .packages = c("foreign") ) %dopar% {
        download_nhanes(file, n)
    }, 
    foreach(file = filenames[1:24], .packages = c("foreign") ) %do% {
        download_nhanes(file, n)
    },
    replications = 5
)
```

## Other Resources  
There are some excellent resources for downloading and using NHANES data.  

1. Anthony Damico has a very comprehensive [site](http://www.asdfree.com) on working with many public-use datasets including NHANES.  The site is well-worth reviewing if you are doing anything with survey data.
2. The NHANES [site](http://www.cdc.gov/nchs/tutorials/Nhanes/Downloads/intro.htm) itself contains R code as well.
3. There are other NHANES repositories if you use GitHub's search function on "nhanes".  One that seems very good is [here](https://github.com/cjendres1/nhanes)

## About Outcomes Insights, Inc.
Outcomes Insights is a small, specialized consulting company with expertise in manipulating and analyzing electronic health data.  One of our goals is to provide open-source tools to help other researchers conduct reproducible research more quicky and accurately.

