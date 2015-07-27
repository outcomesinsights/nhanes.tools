# nhanes.tools
R package to make loading and using NHANES data easier

This package includes functions to download NHANES files from 1999 and later, and store them as .rds files in a data directory on the user's computer.  There are also some simple utilities to merge selected files into useable dataframes using the data.table package.  

The functions in this package will download NHANES data from the CDC's ftp server, including the mortality files.  It was tested on a Mac running Yosemite, R 3.1.3, and RStudio 0.99.447.  I also tested it on Windows 7 via VMware Fusion, R 3.2.1, and RStudio 0.99.467.  It seems to work on both platforms.  There is/was a challenge in properly identifying subdirectories into which the files would be written because Windows doesn't want a trailing slash (/), and Mac likes one.  But if you *do not use* the trailing slash on either platforms, all *should* be well.  

The ftp download sometimes crashes (due to the FTP server, not the code as far as I know).  If that happens, you have to delete the entire wave that was in the process of being downloaded and restart.  Or, if you notice where it failed, you can download from the failure point.  I added "try-catch" functionality to retry downloading and address this possibility, but I have not found a good way to test this to see how well it works.  By the way, thanks to the [downloader package](https://github.com/wch/downloader) for sorting the downloading issues on Windows.

Single waves take 5-10 minutes each on my computer to download and resave as .rds files, which are compressed by default.  Across all waves the data occupy about 250 MB (compressed size) on my hard drive.  I have also included code to do the download in parallel, which, on my 4-core machine gives a little less than a 2-fold speed up.  I also added some progress messages. 

The process also saves a file that lists all the files in the FTP directory.  This listing, and the download process itself, only works on .xpt files and a fixed-width file (.dat) for the mortality data.  There are some .txt files in the ftp directories that are ignored.  

There are also some functions to load the data into your workspace and to merge multiple files for an analysis into a single file (merged by SEQN).  Note that the utilities to merge the files use [data.table](https://github.com/Rdatatable/data.table), but the process could be done with base::merge or [dplyr](https://github.com/hadley/dplyr).  We use data.table for most everything, because it is really fast and has nice utilities like rbindlist() for combining datasets (a fast, simple version of do.call(rbind, list)).

In the future, I will be adding an "nhanes" class to each file, as well as some attributes for the labels, and developing some tools to facilitate common analyses.

## Other Resources  
There are some excellent resources for downloading and using NHANES data.  

1. Anthony Damico has a very comprehensive [site](http://www.asdfree.com) on working with many public-use datasets including NHANES.  The site is well-worth reviewing if you are doing anything with survey data.
2. The NHANES [site](http://www.cdc.gov/nchs/tutorials/Nhanes/Downloads/intro.htm) itself contains R code as well.
3. There are other NHANES repositories if you use GitHub's search function on "nhanes".  One that seems very good is [here](https://github.com/cjendres1/nhanes)

## About Outcomes Insights, Inc.
Outcomes Insights is a small, specialized consulting company with expertise in manipulating and analyzing electronic health data.  One of our goals is to provide open-source tools to help other researchers conduct reproducible research more quicky and accurately.

