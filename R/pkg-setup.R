#' Setup the jaspTools package.
#'
#' Ensures that analyses can be run, tested and debugged locally by fetching all of the basic dependencies.
#' This includes fetching the data library and html files, installing jaspBase and jaspGraphs and adding the required-files.
#' If no parameters are supplied the function will interactively ask for the location of these dependencies.
#'
#' @param pathJaspDesktop [optional] Character path to the root of jasp-desktop if present on the system.
#' @param pathJaspRequiredPkgs [optional] Character path to the root of jasp-required-files if present on the system.
#' @param installJaspModules [optional] Boolean. Should jaspTools install all the JASP analysis modules as R packages (e.g., jaspAnova, jaspFrequencies)?
#' @param quiet [optional] Boolean. Should the installation of R packages produce output?
#' @param force [optional] Boolean. Should a fresh installation of jaspResults, jaspBase, jaspGraphs and the JASP analysis modules proceed if they are already installed on your system?
#'
#' @export setupJaspTools
setupJaspTools <- function(pathJaspDesktop = NULL, pathJaspRequiredPkgs = NULL, installJaspModules = TRUE, quiet = FALSE, force = FALSE) {
  if (interactive()) {

    if (.isSetupComplete()) {
      continue <- menu(c("Yes", "No"), title = "You have previously completed the setup procedure, are you sure you want to do it again?")
      if (continue == 1)
        .removeCompletedSetupFiles()
      else
        return(message("Setup aborted."))
    }

    argsMissing <- FALSE
    if (missing(installJaspModules) || missing(pathJaspRequiredPkgs) || missing(pathJaspDesktop))
      argsMissing <- TRUE

    if (argsMissing)
      message("To fetch the dependencies correctly please answer the following:\n")

    if (missing(pathJaspDesktop)) {
      hasJaspdesktop <- menu(c("Yes", "No"), title = "- Do you have an up-to-date clone of jasp-stats/jasp-desktop on your system?")
      if (hasJaspdesktop == 0) return(message("Setup aborted."))

      if (hasJaspdesktop == 1)
        pathJaspDesktop <- validateJaspResourceDir(readline(prompt = "Please provide path/to/jasp-desktop: \n"), isJaspDesktopDir, "jasp-desktop")
    }

    if (missing(pathJaspRequiredPkgs) && getOS() != "linux") {
      hasJaspRequiredPkgs <- menu(c("Yes", "No"), title = "- Do you have an up-to-date clone of jasp-stats/jasp-required-files on your system?")
      if (hasJaspRequiredPkgs == 0) return(message("Setup aborted."))

      if (hasJaspRequiredPkgs == 1)
        pathJaspRequiredPkgs <- validateJaspResourceDir(readline(prompt = "Please provide path/to/jasp-required-files: \n"), isJaspRequiredFilesDir, "jasp-required-files")
    }

    if (missing(installJaspModules)) {
      wantsInstallJaspModules  <- menu(c("Yes", "No"), title = "- Would you like jaspTools to install all the JASP analysis modules located at github.com/jasp-stats? This is useful if the module(s) you are working on requires functions from other JASP analysis modules.")
      if (wantsInstallJaspModules == 0) return(message("Setup aborted."))

      installJaspModules <- wantsInstallJaspModules == 1
    }

    .setupJaspTools(pathJaspDesktop, pathJaspRequiredPkgs, installJaspModules, quiet, force)

    if (argsMissing)
      printSetupArgs(pathJaspDesktop, pathJaspRequiredPkgs, installJaspModules)
  }
}

.setupJaspTools <- function(pathJaspDesktop = NULL, pathJaspRequiredPkgs = NULL, installJaspModules = TRUE, quiet = FALSE, force = FALSE) {
  pathJaspDesktop <- validateJaspResourceDir(pathJaspDesktop, isJaspDesktopDir, "jasp-desktop")
  pathJaspRequiredPkgs <- validateJaspResourceDir(pathJaspRequiredPkgs, isJaspRequiredFilesDir, "jasp-required-files")

  message("Fetching resources...\n")

  if (is.character(pathJaspRequiredPkgs))
    setLocationJaspRequiredFiles(pathJaspRequiredPkgs)
  else if (is.null(pathJaspRequiredPkgs) && isJaspRequiredFilesLocationSet())
    unlink(getJaspRequiredFilesLocationFileName())

  if (isJaspRequiredFilesLocationSet()) {
    oldLibPaths <- .libPaths()
    on.exit(.libPaths(oldLibPaths))
    .libPaths(c(oldLibPaths, readJaspRequiredFilesLocation())) # we add it at the end so it doesn't actually write to it
  }

  depsOK <- fetchJaspDesktopDependencies(pathJaspDesktop, quiet = quiet, force = force)
  if (!depsOK)
    stop("jaspTools setup could not be completed. Reason: could not fetch the jasp-stats/jasp-desktop repo and as a result the required dependencies are not installed.\n
            If this problem persists clone jasp-stats/jasp-desktop manually and provide the path to `setupJaspTools()` in `pathJaspDesktop`.")

  installJaspPkg("jaspBase", quiet = quiet, force = force)
  installJaspPkg("jaspGraphs", quiet = quiet, force = force)

  if (isTRUE(installJaspModules))
    installJaspModules(force = force, quiet = quiet)

  .setSetupComplete()
  .initJaspToolsInternals()
}

printSetupArgs <- function(pathJaspDesktop, pathJaspRequiredPkgs, installJaspModules) {
  if (is.character(pathJaspDesktop))
    showPathJasp <- paste0("\"", pathJaspDesktop, "\"")
  else
    showPathJasp <- "NULL"

  if (is.character(pathJaspRequiredPkgs))
    showPathPkgs <- paste0("\"", pathJaspRequiredPkgs, "\"")
  else
    showPathPkgs <- "NULL"

  message("\nIn the future you can skip the interactive part of the setup by calling `setupJaspTools(", showPathJasp, ", ", showPathPkgs, ", ", installJaspModules, ")`")
}

validateJaspResourceDir <- function(path, validationFn, title) {
  if (!is.null(path)) {
    if (is.character(path))
      path <- normalizePath(gsub("[\"']", "", path))

    if (!is.character(path) || !do.call(validationFn, list(path = path)))
      stop("Invalid path provided for ", title, "; could not find the correct resources within: ", path)
  }
  return(path)
}

isJaspRequiredFilesDir <- function(path) {
  dirs <- dir(path)
  if (getOS() == "windows")
    return("R" %in% dirs && dir.exists(file.path(path, "R", "library")))
  else if (getOS() == "osx")
    return("Frameworks" %in% dirs && dir.exists(file.path(path, "Frameworks", "R.framework")))
  else if (getOS() == "linux")
    stop("jasp-required-files are not used on Linux")
}

isJaspDesktopDir <- function(path) {
  dirs <- dir(path, pattern = "JASP-*")
  return(all(c("JASP-Common", "JASP-Desktop", "JASP-Engine", "JASP-R-Interface") %in% dirs))
}

findRequiredPkgs <- function(pathToRequiredFiles) {
  result <- ""
  if (isJaspRequiredFilesDir(pathToRequiredFiles)) {
    if (getOS() == "windows")
      result <- getPkgDirWindows(pathToRequiredFiles)
    else if (getOS() == "osx")
      result <- getPkgDirOSX(pathToRequiredFiles)
  }
  return(result)
}

getPkgDirWindows <- function(pathToRequiredFiles) {
  potentialPkgDir <- file.path(pathToRequiredFiles, "R", "library")

  if (dirHasBundledPackages(potentialPkgDir, hasPkg="Rcpp"))
    return(potentialPkgDir)

  return("")
}

getPkgDirOSX <- function(pathToRequiredFiles) {
  basePathPkgs <- file.path(pathToRequiredFiles, "Frameworks", "R.framework", "Versions")
  rVersions <- list.files(basePathPkgs)
  if (identical(rVersions, character(0)))
    return("")

  rVersions <- suppressWarnings(as.numeric(rVersions))
  r <- sort(rVersions, decreasing = TRUE)[1]
  potentialPkgDir <- file.path(basePathPkgs, r, "Resources", "library")

  if (dirHasBundledPackages(potentialPkgDir, hasPkg="Rcpp"))
    return(potentialPkgDir)

  return("")
}

dirHasBundledPackages <- function(dir, hasPkg) {
  if (!dir.exists(dir))
    return(FALSE)

  pkgs <- list.files(dir)
  if (!identical(pkgs, character(0)) && hasPkg %in% pkgs) {
    return(TRUE)
  }

  return(FALSE)
}

getJaspToolsDir <- function() {
  return(.pkgenv[["internal"]][["jaspToolsPath"]])
}

getSetupCompleteFileName <- function() {
  jaspToolsDir <- getJaspToolsDir()
  file <- file.path(jaspToolsDir, "setup_complete.txt")
  return(file)
}

getJaspRequiredFilesLocationFileName <- function() {
  jaspToolsDir <- getJaspToolsDir()
  file <- file.path(jaspToolsDir, "jasp-required-files_location.txt")
  return(file)
}

.isSetupComplete <- function() {
  return(file.exists(getSetupCompleteFileName()))
}

isJaspRequiredFilesLocationSet <- function() {
  return(file.exists(getJaspRequiredFilesLocationFileName()))
}

readJaspRequiredFilesLocation <- function() {
  loc <- NULL
  if (isJaspRequiredFilesLocationSet())
    loc <- readLines(getJaspRequiredFilesLocationFileName())

  return(loc)
}

.setSetupComplete <- function() {
  file <- getSetupCompleteFileName()
  fileConn <- file(file)
  on.exit(close(fileConn))
  writeLines("", fileConn)

  message("jaspTools setup complete")
}

.removeCompletedSetupFiles <- function() {
  unlink(getSetupCompleteFileName())
  unlink(getJaspRequiredFilesLocationFileName())
  unlink(getJavascriptLocation(), recursive = TRUE)
  unlink(getDatasetsLocations(jaspOnly = TRUE), recursive = TRUE)
  message("Removed files from previous jaspTools setup")
}

setLocationJaspRequiredFiles <- function(pathToRequiredFiles) {
  if (!dir.exists(pathToRequiredFiles))
    stop("jasp-required-files folder does not exist at ", pathToRequiredFiles)

  path <- normalizePath(pathToRequiredFiles)
  libPath <- findRequiredPkgs(path)
  if (libPath == "")
    stop("Could not locate the R packages within ", pathToRequiredFiles)

  file <- getJaspRequiredFilesLocationFileName()
  fileConn <- file(file)
  on.exit(close(fileConn))
  writeLines(libPath, fileConn)

  message(sprintf("Created %s", file))
}

# javascript, datasets, jaspResults
fetchJaspDesktopDependencies <- function(jaspdesktopLoc = NULL, branch = "stable", quiet = FALSE, force = FALSE) {
  if (is.null(jaspdesktopLoc) || !isJaspDesktopDir(jaspdesktopLoc)) {
    baseLoc <- tempdir()
    jaspdesktopLoc <- file.path(baseLoc, paste0("jasp-desktop-", branch))
    if (!dir.exists(jaspdesktopLoc)) {
      zipFile <- file.path(baseLoc, "jasp-desktop.zip")
      url <- sprintf("https://github.com/jasp-stats/jasp-desktop/archive/%s.zip", branch)

      res <- try(download.file(url = url, destfile = zipFile, quiet = quiet), silent = quiet)
      if (inherits(res, "try-error") || res != 0)
        return(invisible(FALSE))

      if (file.exists(zipFile)) {
        unzip(zipfile = zipFile, exdir = baseLoc)
        unlink(zipFile)
      }
    }
  }

  if (!isJaspDesktopDir(jaspdesktopLoc))
    return(invisible(FALSE))

  fetchJavaScript(jaspdesktopLoc)
  fetchDatasets(jaspdesktopLoc)
  installJaspResults(jaspdesktopLoc, quiet = quiet, force = force)

  return(invisible(TRUE))
}

getJavascriptLocation <- function(rootOnly = FALSE) {
  jaspToolsDir <- getJaspToolsDir()
  htmlDir <- file.path(jaspToolsDir, "html")
  if (!rootOnly)
    htmlDir <- file.path(htmlDir, "jasp-html")

  return(htmlDir)
}

getDatasetsLocations <- function(jaspOnly = FALSE) {
  jaspToolsDir <- getJaspToolsDir()
  dataDirs <- file.path(jaspToolsDir, "jaspData")
  if (!jaspOnly)
    dataDirs <- c(dataDirs, file.path(jaspToolsDir, "extdata"))

  return(dataDirs)
}

fetchJavaScript <- function(path) {
  destDir <- getJavascriptLocation(rootOnly = TRUE)
  if (!dir.exists(destDir))
    dir.create(destDir)

  htmlDir <- file.path(path, "JASP-Desktop", "html")
  if (!dir.exists(htmlDir))
    stop("Could not move html files from jasp-desktop, is the path correct? ", path)

  file.copy(from = htmlDir, to = destDir, overwrite = TRUE, recursive = TRUE)
  file.rename(file.path(destDir, "html"), getJavascriptLocation())
  message("Moved html files to jaspTools")
}

fetchDatasets <- function(path) {
  destDir <- getDatasetsLocations(jaspOnly = TRUE)
  if (!dir.exists(destDir))
    dir.create(destDir)

  dataDir <- file.path(path, "Resources", "Data Sets")
  if (!dir.exists(dataDir))
    stop("Could not move datasets from jasp-desktop, is the path correct? ", path)

  dataFilePaths <- list.files(dataDir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  if (length(dataFilePaths) > 0) {
    dataFiles <- basename(dataFilePaths)
    for (i in seq_along(dataFilePaths))
      file.copy(dataFilePaths[i], file.path(destDir, dataFiles[i]), overwrite = TRUE)

    message("Moved datasets to jaspTools")
  }
}

installJaspResults <- function(path, quiet = FALSE, force = FALSE) {
  if (!force && "jaspResults" %in% installed.packages())
    return()

  if (isNamespaceLoaded("jaspResults"))
    unloadNamespace("jaspResults")

  jaspResultsDir <- file.path(path, "JASP-R-Interface", "jaspResults")
  if (!dir.exists(jaspResultsDir))
    stop("Could not locate jaspResults inside ", path)

  install.packages(jaspResultsDir, type = "source", repos = NULL, quiet = quiet)
}

# installJaspModules <- function(quiet = TRUE) {
#   repos <- getJaspGithubRepos()
#   for (repo in repos) {
#     if (!is.null(names(repo)) && c("name", "full_name") %in% names(repo)) {
#       if (isRepoJaspRPackage(repo[["name"]]) && !repo[["name"]] %in% installed.packages()) {
#         cat("Installing package:", paste0(repo[["full_name"]], "..."))
#         res <- try(devtools::install_github(repo[["full_name"]], auth_token = getGithubPAT(), upgrade = "never", quiet = quiet), silent = quiet)
#         if (inherits(res, "try-error"))
#           cat(" failed\n")
#         else
#           cat(" succeeded\n")
#       }
#     }
#   }
# }

#' Install a JASP R package from jasp-stats
#'
#' Thin wrapper around devtools::install_github.
#'
#' @param pkg Name of the JASP module (e.g., "jaspBase").
#' @param force Boolean. Should the installation overwrite an existing installation if it hasn't changed?
#' @param auth_token To install from a private repo, generate a personal access token (PAT) in "https://github.com/settings/tokens" and supply to this argument. This is safer than using a password because you can easily delete a PAT without affecting any others. Defaults to the GITHUB_PAT environment variable.
#' @param ... Passed on to \code{devtools::install_github}
installJaspPkg <- function(pkg, force = FALSE, auth_token = NULL, ...) {
  if (is.null(auth_token))
    auth_token <- getGithubPAT()

  devtools::install_github(paste("jasp-stats", pkg, sep = "/"), upgrade = "never", force = force, auth_token = auth_token, ...)
}

#' Install all JASP analysis modules from jasp-stats
#'
#' This function downloads all JASP modules locally and then installs them, to ensure all dependencies between JASP modules are resolved correctly.
#' Useful if you're working on modules that have dependencies on other modules.
#'
#' @param force Boolean. Should JASP reinstall everything or should it only install packages that are not installed on your system?
#' @param quiet Boolean. Should the installation procedure produce output?
#'
#' @export installJaspModules
installJaspModules <- function(force = FALSE, quiet = FALSE) {
  if (isJaspRequiredFilesLocationSet()) {
    oldLibPaths <- .libPaths()
    on.exit(.libPaths(oldLibPaths))
    .libPaths(c(oldLibPaths, readJaspRequiredFilesLocation())) # we add it at the end so it doesn't actually write to it
  }

  res <- downloadAllJaspModules(force, quiet)
  if (length(res[["success"]]) > 0) {
    numWritten <- tools::write_PACKAGES(getTempJaspModulesLocation(), type = "source")
    rdsFile <- file.path(getTempJaspModulesLocation(), "packages.RDS")
    if (numWritten > 0 && file.exists(rdsFile)) {
      localPkgDB <- readRDS(rdsFile)
      installCranDependencies(localPkgDB, quiet = quiet)
      if (length(localPkgDB[, "Package"]) > 0)
        install.packages(localPkgDB[, "Package"], contriburl = paste0("file:///", getTempJaspModulesLocation()), type = "source", quiet = quiet)
    }
  }
}

installCranDependencies <- function(localPkgDB, quiet = FALSE) {
  allDeps <- unlist(tools::package_dependencies(localPkgDB[, "Package"], db = localPkgDB))
  internalDeps <- localPkgDB[, "Package"] # these are the JASP modules
  externalDeps <- setdiff(allDeps, internalDeps) # these are CRAN packages
  missingDeps <- setdiff(externalDeps, installed.packages())
  if (length(missingDeps) > 0)
    install.packages(missingDeps, quiet = quiet)
}

getTempJaspModulesLocation <- function() {
  file.path(tempdir(), "JaspModules")
}

downloadAllJaspModules <- function(force = FALSE, quiet = FALSE) {
  repos <- getJaspGithubRepos()
  result <- list(success = NULL, fail = NULL)
  for (repo in repos) {
    if (!is.null(names(repo)) && c("name", "full_name") %in% names(repo)) {
      if (isRepoJaspModule(repo[["name"]]) && (force || !force && !repo[["name"]] %in% installed.packages())) {
        success <- downloadJaspPkg(repo[["name"]], quiet)
        if (success)
          result[["success"]] <- c(result[["success"]], repo[["name"]])
        else
          result[["fail"]] <- c(result[["fail"]], repo[["name"]])
      }
    }
  }
  message("Successful downloads: ", paste(result[["success"]], collapse = ", "), "\n")
  if (length(result[["fail"]]) > 0)
    message("The following packages could not be downloaded: ", paste(result[["fail"]], collapse = ", "), "\n")
  invisible(result)
}

downloadJaspPkg <- function(repo, quiet) {
  url <- sprintf("https://github.com/jasp-stats/%1$s/%2$s/%3$s", repo, "archive", "master.zip")
  baseLoc <- getTempJaspModulesLocation()
  pkgLoc <- file.path(baseLoc, repo)
  zipFile <- file.path(baseLoc, paste0(repo, ".zip"))

  if (!dir.exists(baseLoc))
    dir.create(baseLoc)

  if (!dir.exists(pkgLoc)) {
    res <- try(download.file(url = url, destfile = zipFile, quiet = quiet), silent = quiet)
    if (inherits(res, "try-error") || res != 0) {
      return(FALSE)
    }

    unzip(zipfile = zipFile, exdir = baseLoc)

    if (dir.exists(paste0(pkgLoc, "-master")))
      file.rename(paste0(pkgLoc, "-master"), pkgLoc)

    devtools::build(pkgLoc, clean_doc = FALSE, quiet = quiet)

    if (dir.exists(pkgLoc))
      unlink(pkgLoc, recursive = TRUE)

    if (file.exists(zipFile))
      unlink(zipFile)
  }

  return(TRUE)
}

isRepoJaspModule <- function(repo) {
  isJaspModule <- FALSE

  repoTree <- githubGET(asGithubReposUrl("jasp-stats", repo, c("git", "trees", "master"), params = list(recursive = "false")))
  if (length(names(repoTree)) > 0 && "tree" %in% names(repoTree)) {
    pathNames <- unlist(lapply(repoTree[["tree"]], `[[`, "path"))
    if (length(pathNames) > 0 && all(c("NAMESPACE", "DESCRIPTION", "R", "inst/Description.qml") %in% pathNames))
      isJaspModule <- TRUE
  }

  return(isJaspModule)
}