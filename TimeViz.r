#!/usr/bin/Rscript
################################################################
## Team Gator (Timeline visualization team)
## Author: Travis Jensen
## Created: 19 SEP 2021
## This program creates an example for our team's visualization 
## implemented using the existing gviz software. It builds upon previous 
## work to utilize a configuration file.
################################################################

## Set CRAN repo to download and install packages from
CRAN="http://cran.rstudio.com/"

## Check and install dependencies function
getDeps <- function(deps){
    print(paste0("Checking if ",deps," is installed"))
    new.packages <- deps[!(deps %in% installed.packages()[,"Package"])]
    if(length(new.packages)){
        print(paste0(new.packages," is/are to be installed"))
        if(new.packages=="Gviz") {
            BiocManager::install("Gviz")
        } else {
            install.packages(new.packages,repos=list(CRAN))
	    }
	} else {
	    print(paste0(deps," is already installed"))	    
	}
    for(pkg in deps){
        print(paste0("Loading ",pkg))
        library(pkg,character.only=TRUE)
    }
}

## Help table function
helpMenu <- function(){
    spec = matrix(c(
        'help'     ,'h',0,"logical"  ,"Help screen",
        'inFile'   ,'i',1,"character","XLSX file to feed",
        'outFile'  ,'o',1,"character","PDF output",
        'verbosity','v',2,"integer"  ,"Verbose logging (optional), default 0",
        'log'      ,'l',2,"character","Log file (optional)"
    ),byrow=TRUE,ncol=5)
    opt=getopt(spec)

    help = "
    R Libraries Required:
    * Biocmanager
    * * Gviz
    * openxlsx
    * stringr
    * getopt

    XLSX Sheet 1 'Configuration' Format
    * Must be named 'Configuration'
    * Column 1\tVariable name\t\tFixed (required tracks)
    * Column 2\tVariable description\tnot parsed
    * Column 3\tValue(s)\t\tMust match variable name (required)

    XLSX Sheets 2-n 'Data and Annotation Tracks 1-n' Format
    * Sheet names must match values in 'Track List' variable list
    * Defined by the 'Track *' variables in a semicolon-separated lists
    * * (Excludes 'Track Box Width' variable)
    * 'Data *' variables define how data tracks are merged in plots
    * First column must be 'Time Ranges' and be semicolon separated
    * * i.e. Time range: 0;20
    * Rows represent different time ranges
    * Columns 2-n must be data or annotation columns
    \n"

## Print help message if no options given or if help is called
    if(!is.null(opt$help)||(is.null(opt$help)&&(is.null(opt$inFile)||is.null(opt$outFile)))) {
        cat(getopt(spec, usage=TRUE))
        cat(help)
        q(status=1)
    }
    if(is.null(opt$verbosity)){opt$verbosity=0}
    return(opt)
}

## Write strings to log file as they are called
writeLog <- function(message){
    if(opt$verbosity>0){
        print(message)
        if(!is.null(opt$log)){
            lapply(c(message),write,opt$log,append=TRUE)
        }
    }
}

## Script starts here
## Pull needed packages in the required order
getDeps(c("getopt"))
opt <- helpMenu()
    
## Load Gviz afterwards because it takes the longest to load
getDeps(c("BiocManager","Gviz","openxlsx","stringr"))

#######################
##
## PARSE Configuration
##
#######################

## import XLSX sheet 1 (configuration)
if(!file.exists(opt$inFile)){
    writeLog(paste0("Error, ",opt$inFile," does not exist"))
    q(status=1)
}
infile.config = opt$inFile
config = read.xlsx(infile.config,sheet='Configuration')

## parse
#out.file = config$Value[config$Variable.Name=='Output PDF']
out.file = opt$outFile
if(file.exists(out.file)){
    writeLog(paste0("Error, ",out.file," already exists. Please use a different file name"))
    q(status=1)
}

# Parse config table in xlsx file
writeLog(paste0("Importing configuration"))
out.height = as.numeric(config$Value[config$Variable.Name=='Output Height'])
out.width = as.numeric(config$Value[config$Variable.Name=='Output Width'])
main.title = config$Value[config$Variable.Name=='Main Title']
main.size = as.numeric(config$Value[config$Variable.Name=='Main Font Size'])
track.width = as.numeric(config$Value[config$Variable.Name=='Track Box Width'])
from.to = as.numeric(unlist(str_split(config$Value[config$Variable.Name=='From To'],';')))
track.sheet.names = unlist(str_split(config$Value[config$Variable.Name=='Track List'],';'))
track.types = unlist(str_split(config$Value[config$Variable.Name=='Track Type'],';'))
track.heights = as.numeric(unlist(str_split(config$Value[config$Variable.Name=='Track Heights'],';')))
track.names = unlist(str_split(config$Value[config$Variable.Name=='Track Names'],';'))
track.box.colors = unlist(str_split(config$Value[config$Variable.Name=='Track Box Color'],';'))
track.bg.color = unlist(str_split(config$Value[config$Variable.Name=='Track Background Color'],';'))
track.label.colors = unlist(str_split(config$Value[config$Variable.Name=='Track Label Color'],';'))
track.label.sizes = as.numeric(unlist(str_split(config$Value[config$Variable.Name=='Track Label Size'],';')))
data.types = unlist(str_split(config$Value[config$Variable.Name=='Data Type'],';'))
data.groups = unlist(str_split(config$Value[config$Variable.Name=='Data Groups'],';'))
data.aggs = unlist(str_split(config$Value[config$Variable.Name=='Data Aggregate'],';'))

## Additional config fields from Seth
main.trackLabelPosition = config$Value[config$Variable.Name=='Timeline Track Label Position']
main.trackDirection = as.numeric(config$Value[config$Variable.Name=='Track Directions'])
main.trackLittleTicks = as.numeric(config$Value[config$Variable.Name=='Track Little Ticks'])
main.trackLineWidth = as.numeric(config$Value[config$Variable.Name=='Track Line Width'])
main.trackShowID = as.numeric(config$Value[config$Variable.Name=='Track Show ID'])
main.trackCexID = as.numeric(config$Value[config$Variable.Name=='Track Cex ID'])
main.trackYAxisTicks = config$Value[config$Variable.Name=='Track Y-axis Ticks']
main.dataBoxRatio = as.numeric(config$Value[config$Variable.Name=='Data Box Ratio'])
main.dataTrackGrid = as.numeric(config$Value[config$Variable.Name=='Data Track Grid'])
main.dataLegend = as.numeric(config$Value[config$Variable.Name=='Data Legend'])
main.trackShape = config$Value[config$Variable.Name=='Shape Annotation']
main.trackAnnotationGroup = config$Value[config$Variable.Name=='Track Directions']
main.groupLabel = config$Value[config$Variable.Name=='Group Labels']
main.trackLineType = as.numeric(config$Value[config$Variable.Name=='Track Line Type'])
main.trackLineWidth = as.numeric(config$Value[config$Variable.Name=='Track Line Width'])
main.showID = config$Value[config$Variable.Name=='Show ID']

## Validate config
## Verify all required track lists have the same number of elements
## Use track.sheet.names and data.types as the expected counts
writeLog(paste0("Validating delimited configuration sections"))
lenTrackSheetNames = length(track.sheet.names)
lenTrackTypes = length(track.types)
lenTrackHeights = length(track.heights)
lenTrackNames = length(track.names)
lenTrackBoxColors = length(track.box.colors)
lenTrackBGColor = length(track.bg.color)
lenTrackLabelColors = length(track.label.colors)
lenTrackLabelSizes = length(track.label.sizes)
lenDataTypes = length(data.types)
lenDataGroups = length(data.groups)
lenDataAggs = length(data.aggs)
expectTrackLen = lenTrackSheetNames
if(lenTrackTypes != expectTrackLen){
    writeLog(paste0("track.types should have ",expectTrackLen," values"))
    q(status=1)
}

## If any required tracks are of null length, throw error

#######################
##
## Prepare Desired Tracks
##
#######################

## initialize plot list object and other variables
plot.list = list()
data.count = 1

## for each track do
for (i in 1:length(track.types)) {
    track.type = track.types[i]
    track.sheet.name = track.sheet.names[i]
    track.name = gsub('\\\\n','\n',track.names[i])
    track.box.color = track.box.colors[i]
    track.label.color = track.label.colors[i]
    track.label.size = track.label.sizes[i]
    
    writeLog(paste0("Processing track: ",track.name))
    
    ## determine track type and append track to list object
    if (track.type=='time') {
        
        ## initialize an axis track and add to plot list object
        ## wishlist: add ticksAt (minor/major ticks based on time units), figure out how to add the title - currently not working
        plot.list[[i]] = GenomeAxisTrack(
            name=track.name,
            background.title=track.box.color,
            background.panel=track.bg.color,
            fontcolor.title=track.label.color,
            cex.title=track.label.size)
    
    ## Data track
    } else if (track.type=='data') {
        data.type = data.types[data.count]
        data.group = unlist(str_split(data.groups[data.count],','))
        data.agg = data.aggs[data.count]
        
        ## Import sheet to get label
        config.data = read.xlsx(
            infile.config,
            sheet=track.sheet.name
        )
      
        ## determine starts and stops
        starts = as.numeric(unlist(lapply(str_split(config.data$Time.Ranges,';'),function(x){x[1]})))
        ends = as.numeric(unlist(lapply(str_split(config.data$Time.Ranges,';'),function(x){x[2]})))
        
        ## pull in a dummy data-set from the examples in the user guide
        config.data.granges = GRanges(
            seqnames = "chrX",
            strand = rep("*",length(starts)),
            ranges = IRanges(start = starts, end=ends),
            mcols=config.data[,2:ncol(config.data)])
        
        ## Is there any grouping?
        ## wishlist: Add group specific color coding, color coding for y-axis (default to white right now)
        if (any(nchar(data.group)==0)) {
            ## plot a data track without grouping
            dTrack <- DataTrack(
                config.data.granges,
                name = track.name,
                type = data.type,
                background.title=track.box.color,
                background.panel=track.bg.color,
                fontcolor.title=track.label.color,
                cex.title=track.label.size)
          
        } else {
            
            ## Aggregate data on the mean?
            if (data.agg=='NULL') {
                ## plot a data track with grouping no aggregate
                plot.list[[i]] = DataTrack(
                    config.data.granges,
                    name = track.name,
                    groups = data.group,
                    type = data.type,
                    aggregateGroups = FALSE,
                    background.title=track.box.color,
                    background.panel=track.bg.color,
                    fontcolor.title=track.label.color,
                    cex.title=track.label.size)
            } else {
                ## plot a data track with  and aggregate
                plot.list[[i]] = DataTrack(
                    config.data.granges,
                    name = track.name,
                    groups = data.group,
                    type = data.type,
                    aggregateGroups = TRUE,
                    background.title=track.box.color,
                    background.panel=track.bg.color,
                    fontcolor.title=track.label.color,
                    cex.title=track.label.size)
            }
        }
       
        ## advance counter
        data.count = data.count + 1
        
    ## annotation Track
    } else if (track.type=='annotation') {
      
        ## Import sheet to get label
        config.annot = read.xlsx(
            infile.config,
            sheet=track.sheet.name)
      
        ## determine starts and stops
        starts = as.numeric(unlist(lapply(str_split(config.annot$Time.Ranges,';'),function(x){x[1]})))
        ends = as.numeric(unlist(lapply(str_split(config.annot$Time.Ranges,';'),function(x){x[2]})))
        
        ## get grouping factor
        group.factor = as.numeric(as.factor(config.annot$Annotation.Name))
        
        ## plot an annotation track
        ## wishlist: how to stagger annotations better? input for box shape, ellipse, arrows...etc, 
        ## plot annotation label above/below/on box, 
        plot.list[[i]] = AnnotationTrack(
            start=starts,
            end=ends,
            chromosome="chrX",
            strand=rep("*",length(starts)), 
            id=gsub('\\\\n','\n',config.annot$Annotation.Name),
            name=track.name,
            shape=main.trackShape,
            featureAnnotation="id",
            group=group.factor,
            stacking="squish",
            fontcolor.feature=config.annot$Annotation.Label.Color,
            cex.feature=config.annot$Annotation.Label.Size,
            fill=config.annot$Annotation.Color,
            background.title=track.box.color,
            background.panel=track.bg.color, 
            fontcolor.title=track.label.color,
            cex.title=track.label.size)
      
    } else { ## invalid input track type -- exit with non-zero status
        writeLog(paste0("Please provide valid track type. The given track type is not valid: ",track.type))
        quit(status=3) ## non 0 exit status
    }
}

#######################
##
## Prepare Desired Tracks
##
#######################

writeLog("Creating PDF")
pdf(
    out.file,
    height=out.height,
    width=out.width)

writeLog("Plotting tracks")
plotTracks(
    plot.list,
    from = from.to[1],
    to = from.to[2],
    cex.main=main.size,
    cex.id=main.trackCexID,
    main=main.title,
    labelPos=main.trackLabelPosition,
    littleTicks=main.trackLittleTicks,
    lwd=main.trackLineWidth,
    sizes=track.heights,
    yTicksAt=main.trackYAxisTicks,
    title.width=track.width)

dev.off()
