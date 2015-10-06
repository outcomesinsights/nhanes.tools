# nhanes.tools
R package to make loading and using NHANES data easier

This package includes functions to download [NHANES](http://www.cdc.gov/nchs/nhanes/about_nhanes.htm) files from 1999 and later, and store them as .rds files in a data directory on the user's computer.  There are also some simple utilities to merge selected files into useable dataframes using the data.table package.  

The functions in this package will download NHANES data from the CDC's http server, including the mortality files which are still on an ftp server.  It was tested on a Mac running Yosemite, R 3.2.2, and RStudio 0.99.484.  I also tested a previous version on Windows 7 via VMware Fusion, R 3.2.1, and RStudio 0.99.467.  It seems to work on both platforms.  However, we did run into an issue with Kaspersky anti-virus on Windows 7 blocking `download.file()`, so if you can't download, try pausing your antivirus/firewall software.  There is/was a challenge in properly identifying subdirectories into which the files would be written because Windows doesn't want a trailing slash (/), and Mac likes one.  But if you **do not use** the trailing slash on either platform, all *should* be well.  

I added the ability to save the downloaded files to a temporary directory.  To accomplish this, leave data_dir empty when running `setup_nhanes()` (which is the default).

The download could possibly crash due to the server or connection, not the code as far as I know.  If that happens, it is probably easiest to reload the entire wave that was in the process of being downloaded.  Or, if you notice where it failed, you can download from the failure point.  I added "try-catch" functionality to retry downloading and address this possibility, but I have not found a good way to test this to see how well it works.  By the way, thanks to the [downloader package](https://github.com/wch/downloader) for sorting the downloading issues on Windows.  And thanks to [ROpenSci](https://ropensci.org) for some [suggestions](https://discuss.ropensci.org/t/data-only-packages/203/4) and code on downloading from FTP sites.

Single waves take 5-10 minutes each on my computer to download and resave as .rds files, which are compressed by default.  Across all waves the data occupy about 250 MB (compressed size) on my hard drive.  I have also included code to do the download in parallel, which, on my 4-core machine gives a little less than a 2-fold speed up.  I also added some progress messages.  Downloading all of the data from 1999-2011 **in parallel** took me just under 18 minutes, and it did not crash (as of 6 October 2015).

I added a function that lists all of the relevant NHANES files, which is stored in an internal dataframe in the package.  The goal is to add a list of all of the NHANES variables as well, to make it easier to find what you are looking for.  

There are also some functions to load the data into your workspace and to merge multiple files for an analysis into a single file (merged by SEQN).  Note that the utilities to merge the files use [data.table](https://github.com/Rdatatable/data.table), but the process could be done with base::merge or [dplyr](https://github.com/hadley/dplyr).  We use data.table for most everything, because it is really fast and has nice utilities like `rbindlist()` for combining datasets (a fast, simple version of `do.call(rbind, list))`.

In the future, I plan to add an "nhanes" class to each file, as well as some attributes for the labels, and developing some tools to facilitate common analyses.  Right now there is a simple function to create a survey design object.  It requires that you supply the proper weight variable.  Also, there is a function to generate a nicely formatted summary of simple survey outputs (total counts and proportions using svymean, svyby, and svytotal).  It might work for other survey functions too.

## To Install and Use
Install using devtools. Make sure Rcpp is installed for devtools to work properly.  (On Windows, you also need to install Rtools.)

```R
library(devtools)
install_github(repo = "outcomesinsights/nhanes.tools")
library(nhanes.tools)
```
Below is some sample code for downloading the entire NHANES data.  The "[1:7]" is optional, but shows how you might download just a few waves (for example [6:7] will give the last 2 waves).  Note that this will write all of the .rds files to a subdirectory of the data directory specified in the `setup_nhanes()` function.  So, make sure this is where you want the files to be saved.  In the example below, it is writing to the project data directory ("./data/"), in the subdirectory called "raw".  Eventually this will all be wrapped into a simpler function.  

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

Below is a way to do a single year using parallel downloading.  To do all waves in parallel, you just need to wrap the `foreach` call below in the above loop (replace the download_nhanes for loop).  The code below uses "filenames[1:5]" which will download the first 5 files.  Just delete `[1:5]` to download all files in the wave.

```R
library(foreach)
library(doMC)
registerDoMC(cores = 4)

foreach(file = filenames[1:5], .packages = c("foreign", "downloader"), .combine = rbind) %dopar% {
    download_nhanes(file, n, console = FALSE)
}
```
This shows how to download a subset of files.  You have to create the character vector "filenames" first, as shown above.  For 1999, this will download the last 5 files, plus the mortality file (6 files total).
```R
for(file in filenames[110:115]){
        download_nhanes(file, n)
    }
```

This is some code to compare parallel vs. serial downloading using the first 24 files of a given year.
```R
# compare parallel vs serial downloading (serial ~ 1.75x parallel download time)
library(rbenchmark)
benchmark(
    foreach(file = filenames[1:24], .packages = c("foreign", "downloader")) %dopar% {
        download_nhanes(file, n)
    }, 
    foreach(file = filenames[1:24], .packages = c("foreign", "downloader")) %do% {
        download_nhanes(file, n)
    },
    replications = 5
)
```
## Analyses

We have a [blog post](http://outins.com/2015/07/10/nhanes-data-in-r/) that goes through some example analyses that may be helpful to some people.  Note that the package has evolved from the versions of the scripts used in the blog, but you should still get the idea.

## Issues
We learned that selected files (e.g.,  medication [RX]) have multiple records per person.  So, in this case, the `load_merge()` function will return a list.  The first item will be the data, and the second item will be a list of data.frames with multiple records per person.  These are pretty rare -- they seem to be for prescription drugs and for dietary questionnaires.  Unless you are using these files, you should just get a dataframe back.

Also note that the FTP server files appear to be slightly different from the files available on the NHANES website.  We just changed to downloading from the HTTP site instead.  This is a [link](https://gist.github.com/markdanese/112c3ccb0f98bd640d24) to code that generates the necessary dataframe with links, in case you are interested.

Right now there are a few files that span multiple waves.  These are generally for drugs and dietary files, plus some studies done with stored serum.  These are downloaded with every wave.

## Other Resources  
There are some excellent resources for downloading and using NHANES data.  

1. Anthony Damico has a very comprehensive [site](http://www.asdfree.com) on working with many public-use datasets including NHANES.  The site is well-worth reviewing if you are doing anything with survey data.
2. The NHANES [site](http://www.cdc.gov/nchs/tutorials/Nhanes/Downloads/intro.htm) itself contains R code as well.
3. There are other NHANES repositories if you use GitHub's search function on "nhanes".  One that seems very good is [here](https://github.com/cjendres1/nhanes)

## About Outcomes Insights, Inc.
Outcomes Insights is a small, specialized consulting company with expertise in manipulating and analyzing electronic health data.  One of our goals is to provide open-source tools to help other researchers conduct reproducible research more quicky and accurately.

