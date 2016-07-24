library(data.table)
args=commandArgs(trail=T)
OUTPUT=args[1]
SAMPLENAME=args[2]
blocks=args[3:len(args)]

for(i in seq(len(blocks))){
    cat("block[",i,"]:",blocks[i],"\n")

    d1=fread(paste0(blocks[i],"__PosHM.txt"))
    if(!exists("dMap")){
        dMap=d1
        colnames(dMap)[3]="POS"
        dMap$NEG=0
    } else {
        dMap$POS=dMap$POS+d1$V3
    }
    d1=fread(paste0(blocks[i],"__NegHM.txt"))
    dMap$NEG=dMap$NEG+d1$V3
}

dd=as.data.frame(dMap)
colnames(dd)[1:2]=c("CHROM","POS")
colnames(dd)[3]=cc(SAMPLENAME,"POS")
colnames(dd)[4]=cc(SAMPLENAME,"NEG")
save(dd,file=OUTPUT,compress=T)
