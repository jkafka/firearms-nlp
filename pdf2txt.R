#!/usr/bin/env Rscript
### Convert, ocr pdf/tif court documents
### 
### Kaidi Chen (陈凯迪), Ott (奥特) Toomet 
### [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
###
library(magick)  # image conversion
library(pdftools)
library(magrittr)
library(foreach)
library(tesseract)

## ---------- parameters to adjust ----------
## Verbosity: larger number prints more info
printLevel <- 2

## output file name.  The final data frame will be stored in this file
## in the current folder.
## There will also be images/converted text in PNGDIR and TXTDIR
outFName <- "converted-results.Rdat"

## How many cases to sample: 0 = everything
## This is useful for troubleshooting, e.g. set 'sample <- 10'
sample <- 0

## Folders:
## DATADIR: the main folder where all the data is
## CASEDIR: the folder where are scanned docs
## PNGDIR: folder to put the converted png-s.
##         this will be created as needed, and normally deleted afterwards
## TXTDIR: folder to put the converted texts, page-by-page
##         It is not needed for the final data file, but may be handy
##         for troubleshooting, or if you need the converted texts for
##         other purposes
DATADIR <- "/home/siim/bigdata/firearms-nlp/"
CASEDIR <- file.path(DATADIR, "court-docs-scanned")
PNGDIR <- file.path(DATADIR, "converted-pngs")
TXTDIR <- file.path(DATADIR, "converted-text")

## ---------- end of the adjustment parameters ----------

## ---------- Do you run if from command line?  Ignore if you do not
if(require(argparser)) {
   args <- argparser::arg_parser("Convert all pdf/tif case images to text") %>%
      argparser::add_argument("--sample", "how many cases to sample, 0 = all", 0L) %>%
      argparser::add_argument("--printLevel", "print level, larger number prints more", 1L) %>%
      argparser::parse_args()
   printLevel <- args$printLevel
   sample <- args$sample
}
if(printLevel > 0) {
   cat("sample", sample, "cases\n")
}

## input files with full pathnames
if(!file.exists(CASEDIR)) {
   paste("Cannot load case files:
no such directory:\n",
CASEDIR) %>%
   stop()      
}
fNames <- list.files(path = CASEDIR, recursive = TRUE, full.names = TRUE)
nExposure <- grep("Exposure Cases", fNames) %>%
   length()
nOutcome <- grep("Outcome Cases", fNames) %>%
   length()
nPdf <- grep(r"(.pdf$)", tolower(fNames)) %>%
   length()
nTif <- grep(r"(.tiff?$)", tolower(fNames)) %>%
   length()
if(printLevel > 0) {
   cat("Found", length(fNames), "files in", CASEDIR, "\n",
       nExposure, "exposure cases and", nOutcome, "outcome cases\n",
       nPdf, "pdf files and", nTif, "tif files\n")
}

if(sample > 0) {
   fNames <- fNames %>%
      sample(sample)
}

## Create output folders
if(printLevel > 0) {
   cat("Creating output folders\n")
}
dir.create(PNGDIR, recursive = TRUE, showWarning = FALSE)
dir.create(TXTDIR, recursive = TRUE, showWarning = FALSE)
errors <- NULL

if(printLevel > 0) {
   cat("Converting pdf-s to text\n")
}
results <- NULL  # final data frame
for(i in seq(along.with = fNames)) {
   path <- fNames[i]
   if(printLevel > 1) {
      cat(i, "/", length(fNames), ": ", path, "\n", sep = "")
   }
   subfolder <- basename(dirname(path))
   filename <- basename(path)
   ## Create folder paths
   pngFolder <- dirname(path) %>%
      sub(CASEDIR, PNGDIR, .)
   txtFolder <- dirname(path) %>%
      sub(CASEDIR, TXTDIR, .)
   pngFolder %>%
      dir.create(recursive = TRUE, showWarning = FALSE)
   txtFolder %>%
      dir.create(recursive = TRUE, showWarning = FALSE)
   ## Exposure or outcome cases
   type <- if(grepl("exposure cases", tolower(path))) "exposure" else "outcome"
   caseText <- NULL
   if (grepl(".pdf$", path)) {
      ## Load the pdf page-by-page.  This is in order to avoid
      ## imageMagick ressource exhaustion when converting large pdf files
      ## at high density
      nPages <- pdf_info(path)$pages
      for(page in seq(length.out = nPages)) {
         pngPath <- sub(CASEDIR, PNGDIR, path) %>%
            sub(".(pdf|PDF)$", sprintf("-%03d.png", page), .)
         txtPath <- sub(CASEDIR, TXTDIR, path) %>%
            sub(".(pdf|PDF)$", sprintf("-%03d.txt", page), .)
         ## Load image.  If loading not successful, the result will be the
         ## error message, not image
         pageImg <- tryCatch(
            image_read_pdf(path, density = 200, pages = page),
            error = function(e) {
            errors <- c(errors, msg <- paste0("\n(PDF) Error while reading file ",
                                             i, "/", length(fNames), ": ",
                                             pngPath))
            cat(msg, "\n")
            print(e)
         })
         if(inherits(pageImg, "magick-image")) {
                           # did we manage to load it?
            tryCatch(
               image_write(pageImg, path = pngPath, format = "png"),
               error = function(e) {
               errors <- c(errors, msg <- paste0("\n(PDF) error while writing file ",
                                                 i, "/", length(fNames), ": ",
                                                 pngPath))
               cat(msg, "\n")
               print(e)
               cat("--\n")
            })
         }
         if(file.exists(pngPath)) {
                           # did we manage to write it?
            pageText <- tryCatch(ocr(pngPath),
                                 error = function(e) {
               errors <- c(errors, msg <- paste("(pdf) error while ocr-ing file:", path))
               cat("\n", msg, "\n")
               print(e)
               ""  # empty string for error
            })
         } else ""
                           # apparently could not write the png file ->
                           # empty string
         writeLines(pageText, txtPath)
         caseText <- c(caseText, pageText)
      }
   } else {
      ## tif files
      img <- tryCatch(image_read(path),
                           # should do it by page but I do not see a way to
                           # extract page images from a tif
                      error = function(e) {
         erros <- c(errors, msg <- paste("(TIF) Cannot read image", path))
         cat("\n", msg, "\n")
         print(e)
         NULL
      })
      if(inherits(img, "magick-image")) {
                           # reading successful
         nPages <- length(img)
         for(page in seq(length.out = nPages)) {
            pngPath <- sub(CASEDIR, PNGDIR, path) %>%
               sub(".(tiff?|TIFF?)$", sprintf("-%03d.png", page), .)
            txtPath <- sub(CASEDIR, TXTDIR, path) %>%
               sub(".(tiff?|TIFF?)$", sprintf("-%03d.txt", page), .)
            tryCatch(image_write(img[page], path = pngPath, format = "png"),
                     error = function(e) {
               errors <- c(errors, msg <- paste("(TIF) Cannot write image", pngPath))
               cat(msg, "\n")
               print(e)
            })
            if(file.exists(pngPath)) {
               pageText <- tryCatch(ocr(pngPath),
                                    error = function(e) {
                  errors <- c(errors, msg <- paste("(TIF) Error while ocr-ing image", pngPath))
                  cat(msg, "\n")
                  print(e)
                  ""  # empty string for error
               })
            } else ""
            writeLines(pageText, txtPath)
            caseText <- c(caseText, pageText)
         }
      } else {
         caseText <- NULL
         nPages <- 0
      }
   }
   if(printLevel > 2) {
      cat("  ", nPages, "pages\n")
   }
   ## remove line/page breaks
   caseText <- paste(caseText, collapse = "\f") %>%
      gsub(r"((\n|\f))", " ", .)
   ## Add the subfolder name, filename, and text to the data frame
   results <- results %>%
      rbind(
         data.frame(subfolder = subfolder, filename = filename, pages = nPages,
                    type = type,
                    text = caseText)
      )
}

save(results, file = outFName)
if(printLevel > 0) {
   cat(nrow(results), "pages saved to", outFName, "\n")
}
if(length(errors) > 0) {
   cat("There were errors:\n\n",
       paste(" -", errors, collapse = "\n"),
       "\n\n")
} else {
   cat("No errors!\n")
}
cat("all done :-)\n")
