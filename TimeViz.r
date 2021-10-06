#!/usr/bin/Rscript
################################################################
## Team Gator (Timeline visualization team)
## Author: Travis Jensen
## Created: 19 SEP 2021
## This program creates an example for our team's visualization 
## implemented using the existing gviz software. It builds upon previous 
## work to utilize a configuration file.
################################################################

## pull needed packages
library(Gviz)
library(openxlsx)
library(stringr)
library(getopt)

## Parse options from stdin
spec = matrix(c(
  'help','h',0,"logical","Help screen",
  'inFile','i',1,"character","xlsx file to feed",
  'outFile','i',1,"character","pdf file output"
), byrow=TRUE, ncol=5)

## set working directory
infile.config = '/Users/travisjensen/Desktop/Working/capstone/working_copies/TimeVizConfig.xlsx'

#######################
##
## PARSE Configuration
##
#######################

## import XLSX sheet 1 (configuration)
config = read.xlsx(infile.config,sheet='Configuration')

## parse
out.file = config$Value[config$Variable.Name=='Output PDF']
out.height = as.numeric(config$Value[config$Variable.Name=='Output Height'])
out.width = as.numeric(config$Value[config$Variable.Name=='Output Width'])
main = config$Value[config$Variable.Name=='Main Title']
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
    
    ## determine track type and append track to list object
    if (track.type=='time') {
        
        ## initialize an axis track and add to plot list object
        ## wishlist: add ticksAt (minor/major ticks based on time units), figure out how to add the title - currently not working
        plot.list[[i]] = GenomeAxisTrack(name=track.name,background.title=track.box.color,background.panel=track.bg.color,
            fontcolor.title=track.label.color, cex.title=track.label.size)
    
    ## Data track
    } else if (track.type=='data') {
        data.type = data.types[data.count]
        data.group = unlist(str_split(data.groups[data.count],','))
        data.agg = data.aggs[data.count]
        
        ## Import sheet to get label
        config.data = read.xlsx(infile.config,sheet=track.sheet.name)
      
        ## determine starts and stops
        starts = as.numeric(unlist(lapply(str_split(config.data$Time.Ranges,';'),function(x){x[1]})))
        ends = as.numeric(unlist(lapply(str_split(config.data$Time.Ranges,';'),function(x){x[2]})))
        
        ## pull in a dummy data-set from the examples in the user guide
        config.data.granges = GRanges(seqnames = "chrX", strand = rep("*",length(starts)),
            ranges = IRanges(start = starts, end=ends),mcols=config.data[,2:ncol(config.data)])
        
        ## Is there any grouping?
        ## wishlist: Add group specific color coding, color coding for y-axis (default to white right now)
        if (any(nchar(data.group)==0)) {
            ## plot a data track without grouping
            dTrack <- DataTrack(config.data.granges, name = track.name, type = data.type,
                background.title=track.box.color, background.panel=track.bg.color,
                fontcolor.title=track.label.color, cex.title=track.label.size)
          
        } else {
            
            ## Aggregate data on the mean?
            if (data.agg=='NULL') {
                ## plot a data track with grouping no aggregate
                plot.list[[i]] = DataTrack(config.data.granges, name = track.name, groups = data.group, 
                    type = data.type,background.title=track.box.color, background.panel=track.bg.color,
                    fontcolor.title=track.label.color, cex.title=track.label.size)
            } else {
                ## plot a data track with  and aggregate
                plot.list[[i]] = DataTrack(config.data.granges, name = track.name, groups = data.group, 
                    type = data.type, aggregateGroups = TRUE, background.title=track.box.color, 
                    background.panel=track.bg.color, fontcolor.title=track.label.color, cex.title=track.label.size)
            }
        }
       
        ## advance counter
        data.count = data.count + 1
        
    ## annotation Track
    } else if (track.type=='annotation') {
      
        ## Import sheet to get label
        config.annot = read.xlsx(infile.config,sheet=track.sheet.name)
      
        ## determine starts and stops
        starts = as.numeric(unlist(lapply(str_split(config.annot$Time.Ranges,';'),function(x){x[1]})))
        ends = as.numeric(unlist(lapply(str_split(config.annot$Time.Ranges,';'),function(x){x[2]})))
        
        ## get grouping factor
        group.factor = as.numeric(as.factor(config.annot$Annotation.Name))
        
        ## plot an annotation track
        ## wishlist: how to stagger annotations better? input for box shape, ellipse, arrows...etc, 
        ## plot annotation label above/below/on box, 
        plot.list[[i]] = AnnotationTrack(start = starts, end = ends, chromosome = "chrX", strand = rep("*",length(starts)), 
            id = gsub('\\\\n','\n',config.annot$Annotation.Name), name = track.name, shape = "box", featureAnnotation = "id",
            group=group.factor, stacking="squish",fontcolor.feature=config.annot$Annotation.Label.Color,cex.feature=config.annot$Annotation.Label.Size,
            fill=config.annot$Annotation.Color, background.title=track.box.color, background.panel=track.bg.color, 
            fontcolor.title=track.label.color, cex.title=track.label.size)
      
    } else { ## invalid input track type -- exit with non-zero status
        print(paste0("Please provide valid track type.  The given track type is not valid: ",track.type))
        quit(status=3) ## non 0 exit status
    }
}

#######################
##
## Prepare Desired Tracks
##
#######################

pdf(out.file,height=out.height,width=out.width)

plotTracks(plot.list, from = from.to[1], to = from.to[2], sizes=track.heights,main=main,cex.main=main.size,
    title.width=track.width)

dev.off()
