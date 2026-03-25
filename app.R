# app.R

#********************************************************
#                     Load Packages
#********************************************************
if(!require("shiny")) install.packages("shiny")
if(!require("xts")) install.packages("xts")
if(!require("quantmod")) install.packages("quantmod")
if(!require("PerformanceAnalytics")) install.packages("PerformanceAnalytics")
if(!require("ggplot2")) install.packages("ggplot2")
if(!require("DT")) install.packages("DT")
if(!require("quadprog")) install.packages("quadprog")
if(!require("ggfortify")) install.packages("ggfortify")
if(!require("tableHTML")) install.packages("tableHTML")
if(!require("colorDF")) install.packages("colorDF")
if(!require("ggthemes")) install.packages("ggthemes")
if(!require("lubridate")) install.packages("lubridate")
if(!require("HierPortfolios")) install.packages("HierPortfolios")
if(!require("corrplot")) install.packages("corrplot")
if(!require("Matrix")) install.packages("Matrix")

library(shiny)
library(xts)
library(quantmod)
library(PerformanceAnalytics)
library(ggplot2)
library(DT)
library(quadprog)
library(ggfortify)
library(tableHTML)
library(colorDF)
library(ggthemes)
library(lubridate)
library(HierPortfolios)
library(corrplot)
library(Matrix)

# UI
ui <- fluidPage(
  
  titlePanel("Portfolio Analysis"),
  
  # Insert Picture
  # p(a(img(src="MCU.png", height = 250, width = 500),
  #     target="_blank")),
  
  p(a(img(src="NTUTIF.png", height = 100, width = 200),
      target="_blank")),  
  
  sidebarPanel(
    fluidRow(column(6,
                    dateRangeInput("dates",
                                   "Sample Period",
                                   start = paste0(as.numeric(substr(Sys.Date(),1,4))-5-1,"-12-01"),
                                   end = as.character(Sys.Date())), ### End of DateRange
    )),
    textInput("symbol","Enter the stock symbol, # of symbols > =3",
              value = ""),
    
    p("NOTE: Only stock symbols separated by space are allowed "),
    numericInput("RF", "Risk-Free Rate ",value = 0.02,
                 step =0.001, min = 0),
    hr(), # add a horizontal line
    uiOutput("seasonality_symbol_selector"),  # Dynamic select input
    numericInput("nY", "Number of Years for Seasonality Analysis",value = 5,
                 step =1, min = 1),
    actionButton("Submit", "Submit") # Move submit Button to the bottom
    
  ),
  
  ### Main Panel
  mainPanel(#poistion="right",
    
    tabsetPanel(type="tab",
                
                tabPanel("Risk profile",
                         plotOutput("plotRET"),
                         h3("Statistics"),
                         #verbatimTextOutput("skew"),
                         #verbatimTextOutput("kurt"),
                         #p("Value at Risk"),
                         #verbatimTextOutput("var"),
                         #textOutput("annRet"),
                         #textOutput("std"),
                         dataTableOutput("Table"), # changed to dataTableOutput
                         h6("References"),
                         p("The application has solely been created for academic purposes only."),
                         p("R packages used: PerformanceAnalytics, quantmod, tseries,shiny")
                ),
                
                tabPanel("Correlation",
                         h4("Correlation between the securities"),
                         plotOutput("plotCor", width = "1000px", height = "1000px") # 調整寬度和高度
                ),
                
                tabPanel("HRP Portfolio", # Add the HRP Portfolio tab panel
                         h2("Hierarchical Risk Parity Portfolio Returns"),
                         plotOutput("plotHRP")  # Plot for HRP Portfolio
                ),
                
                tabPanel("Portfolio",
                         h2("Minimimum variance potfolio"),
                         plotOutput("plotOpt"),
                         h4("Optimised weights for the given stocks in percenatges are"),
                         dataTableOutput("wt")
                ),
                
                tabPanel("Annualized Table",
                         verbatimTextOutput("tab"),
                         plotOutput("plotPrices")
                ),
                tabPanel("Return Seasonalities",
                         dataTableOutput('Sea'))
    )
  )  # End of Main Panel
)

# Server
server <- function(input, output, session){
  
  #options(repr.plot.width = 10, repr.plot.height = 10)
  
  Sys.setlocale("LC_TIME","english")
  
  # Dynamic UI for select input
  output$seasonality_symbol_selector <- renderUI({
    tickers <- unlist(strsplit(input$symbol, " "))
    selectInput("seasonality_symbol", "Select Stock for Seasonality Analysis", choices = tickers)
  })
  
  # Stock price data
  CP <- eventReactive(input$Submit, { # Changed to eventReactive
    
    Start = input$dates[1]
    End = input$dates[2]
    Tickers <- sort(unlist(strsplit(input$symbol, " ")))
    
    #splitting the input
    syms <- sort(unlist(strsplit(input$symbol, " ")))
    Stocks = lapply(syms, function(sym) {
      na.omit(getSymbols(sym,
                         from = Start,
                         to = End,
                         auto.assign=FALSE,
                         src="yahoo")[,6])
    })
    
    #removing na's for stocks which dont have 10 yr data
    x <- do.call(cbind, Stocks)
    # Prices<-x[complete.cases(x), ]
    Prices<-na.locf(x)
    colnames(Prices) <- Tickers
    
    
    end_points <- endpoints(Prices,"months")
    
    CP <- Prices[end_points,]
    
    return(CP)
    
  }) # End of Prices
  
  # Returns
  returns<-reactive({
    rets <- Return.calculate(CP())[-1]
    # remove rows with any NA values
    # rets <- rets[complete.cases(rets),]
    return(rets)
  })
  
  #-----  HRP portfolio calculation
  
  
  HRP_Plot <- reactive({
    rets <- returns()
    if (is.null(rets) || ncol(rets) == 0) return(NULL)
    
    hrp_plot <- tryCatch({
      HRP_Portfolio(cov(rets,use = "pairwise.complete.obs"), graph = TRUE)
    }, error = function(e) {
      print(paste("Error in HRP_Portfolio:", e))
      return(NULL)
    })
    return(hrp_plot)
  })
  
  
  
  
  
  avgR <- reactive({
    return(apply(returns(),2,mean,na.rm=T))
  })
  
  stdV <- reactive({
    return(apply(returns(),2,sd,na.rm=T))
  })
  
  covMat <- reactive({
    return(cov(returns(),use = "pairwise.complete.obs"))
  })
  
  opt <- reactive({
    
    nFreq <- 12
    nPoints <- 100
    minW <- 0.00  # Min Weight
    maxW <- 1.00  # Max Weight
    
    # Ann Ret
    avgRET <- matrix(avgR()*nFreq,ncol=1)
    stdev <-  matrix(stdV()*nFreq^0.5,ncol=1)
    covmat <- matrix(covMat()*nFreq,
                     ncol=length(avgR()),
                     nrow=length(avgR()))
    # Parms for solve.QP
    mean.R <- matrix(avgR(),ncol=1)
    cov.mat <- matrix(covMat()*nFreq,
                      ncol=length(avgR()),
                      nrow=length(avgR()))
    
    mu.P <- seq(min(mean.R + 5e-12),
                max(mean.R - 5e-12),
                length = nPoints) ## set
    
    Weight <- NULL
    PortR <- NULL
    PortV <- NULL
    for (i in 1:length(mu.P)) {
      n <- ncol(cov.mat)
      dvec.set <- array(0, dim=c(n,1))
      Amat.set <- cbind(rep(1, n), mean.R, diag(n), 1*diag(n), -1*diag(n))
      bvec.set <- 1
      meq.set  <- 2
      min.wgt <-rep(minW , n)
      max.wgt <-rep(maxW, n)
      bvec.set <- c(bvec.set, mu.P[i], rep(0, n),min.wgt, -max.wgt)
      port <- solve.QP(Dmat=nearPD(cov.mat)$mat, dvec=dvec.set, Amat=Amat.set,
                       bvec=bvec.set, meq=meq.set)
      Weight <- rbind(Weight,port$solution)
      PortR <- rbind(PortR,
                     (t(port$solution)%*%avgRET))
      PortV <- rbind(PortV,
                     sqrt(t(port$solution)%*%covmat%*%port$solution))
      rm(port)
    }
    Port <- round(cbind(PortR,PortV,PortR/PortV,Weight),digits = 4)
    colnames(Port) <- c("RET","SD","RET/SD",names(avgR()))
    
    SV <- 3;   # Sorting by indicators. 1=RET, 2=VOL, 3=RET/VOL
    
    Port <- Port[order(Port[,SV],decreasing = T), ]
    opt <- Port
    return(opt)
    
  })
  
  wts<-reactive({
    return(opt())
  })
  
  
  #getting output using desired functions
  
  ### Panel 1
  output$plotRET <- renderPlot(autoplot(returns(),ts.colour = 'orange')+theme_hc())
  # output$skew <- renderPrint(round(skewness(returns()),2))
  # output$kurt <- renderPrint(round(kurtosis(returns()),2))
  # output$var <- renderPrint(round(VaR(returns()),2))
  
  # Table stats
  output$Table <- renderDataTable({
    stats_matrix <- table.Stats(returns())
    
    # Define rows to remove
    rows_to_remove <- c("UCL Mean (0.95)", "LCL Mean (0.95)", "SE Mean", "Variance")
    
    # Convert to data frame and remove specified rows
    stats_df <- as.data.frame(round(stats_matrix, 2))
    stats_df <- stats_df[!(rownames(stats_df) %in% rows_to_remove), , drop = FALSE]
    
    datatable(stats_df, class = 'cell-border stripe',
              options = list(dom = 't', pageLength = nrow(stats_df),
                             columnDefs = list(list(className = 'dt-center', targets = '_all')),
                             initComplete = JS(
                               "function(settings, json) {",
                               "$(this.api().table().header()).css({'background-color': '#d1e0e0', 'color': 'black'});",
                               "}")))
  })
  
  # Panel 2
  output$wt <- renderDataTable({
    round(as.data.frame(wts()),2)
  })
  
  output$plotOpt<-renderPlot({
    Port <- opt()
    adj = 0.30
    nFreq <- 12
    avgRET <- matrix(avgR()*nFreq,ncol=1)
    stdev <-  matrix(stdV()*nFreq^0.5,ncol=1)
    rf <- input$RF
    SV2 <- 2;   # Sorting by indicators. 1=RET, 2=VOL, 3=RET/VOL
    SV3 <- 3;   # Sorting by indicators. 1=RET, 2=VOL, 3=RET/VOL
    gmin.port <- Port[order(Port[,SV2],decreasing = F)[1],]
    tan.port <- Port[order(Port[,SV3],decreasing = T)[1],]
    
    plot(Port[,1]~Port[,2],
         xlim = c(min(stdev)-min(stdev)*adj,
                  max(stdev)+max(stdev)*adj),
         ylim = c(min(avgRET)-min(avgRET)*(adj/10),
                  max(avgRET)+min(avgRET)*(adj/10)),
         xlab = 'risk(sd)', ylab = 'return',
         main = 'Feasible Investment Set', col = 'navyblue')
    
    
    cols <- ifelse(avgRET > 0, 'red','black')
    points(stdev, avgRET, pch = 8, cex = 1.4, col = cols)
    text(stdev, avgRET, names(avgR()),
         col = cols, cex = 0.70, adj = -.2)
    
    points(gmin.port[1]~gmin.port[2], col="green", pch=16, cex=2)
    points(tan.port[1]~tan.port[2], col="red", pch=16, cex=2)
    
    text(gmin.port[1]~gmin.port[2], labels="GLOBAL MIN", pos=2,col="green")
    text(tan.port[1]~tan.port[2], labels="TANGENCY", pos=1,col = "red")
    
    sr.tan = (tan.port[1]- rf)/tan.port[2]
    abline(a=rf, b=sr.tan, col="green", lwd=2)
  })
  
  output$plotCor<-renderPlot({
    cor_matrix <- cor(returns(),use = "pairwise.complete.obs")
    
    # Check if cor_matrix has any NA or not finite values
    if (any(is.na(cor_matrix)) || any(!is.finite(cor_matrix))) {
      plot(1, type="n", axes=FALSE, xlab="", ylab="",
           main="Correlation matrix could not be calculated due to NA values.")
      return()
    }
    
    ord <- corrMatOrder(cor_matrix, order = "alphabet")
    Cor <- cor_matrix[ord,ord]
    
    # Set color limits for consistent color scale
    col_limits <- c(-1, 1)
    
    Sig <- cor.mtest(Cor, conf.level = .95)
    corrplot.mixed(Cor, tl.pos = "lt",
                   diag = "l",
                   #p.mat = Sig$p,
                   sig.level = .05,
                   tl.cex = 1.5, 
                   tl.offset = 0, 
                   tl.srt = 90)
    
    
    #  Display numbers on correlation
    corrplot(Cor, method = "number", # Use "number" for displaying numbers on lower triangle
             type = "lower",        # Display only lower triangle
             diag = FALSE,        # Remove diagonal 
             tl.pos = "n",         # Remove label
             add = TRUE,   # add numbers to an existing plot
             cl.pos ="n",
             number.cex = 1.2,  # Adjust the number size
             number.font = 1,
             col="black")
    
    
    title(main = list("", cex = 2.0,
                      col = "red", font = 3),line = 1.5)
  })
  
  
  output$tab<-renderPrint(table.AnnualizedReturns(returns(),
                                                  scale = 12,
                                                  geometric = F))
  output$plotPrices<-renderPlot(chart.TimeSeries(CP(),main="Prices",
                                                 legend.loc="topleft",
                                                 auto.grid = T)
  )
  
  # Panel 3: HRP Portfolio Plot
  output$plotHRP <- renderPlot({
    hrp_plot <- HRP_Plot()
    if(!is.null(hrp_plot)) {
      hrp_plot # Return the HRP plot directly
    } else{
      NULL
      #  ggplot() + geom_text(aes(x=0, y=0, label="No data for HRP Portfolio"), size=5) + theme_void()
    }
  })
  
  
  
  ### Panel 5: Return Seasonality
  StrategyInput <- reactive({ # Now a reactive expression
    
    rets <- returns()
    
    if(is.null(rets) || ncol(rets) == 0 ) return(NULL)
    
    # Use selected ticker for seasonality analysis
    Ticker <- input$seasonality_symbol
    
    if (is.null(Ticker) || Ticker == "" ) return(NULL) # if no ticker is selected or it is empty, return NULL
    
    
    # Filter returns for the selected ticker
    rets_filtered <- rets[, Ticker, drop = FALSE]  # Use drop = FALSE to keep it as an xts
    
    #
    if (is.null(rets_filtered) || nrow(rets_filtered) == 0) return(NULL)
    
    #********************************************************
    #                   Parms
    #********************************************************
    nYears <- input$nY  # Number of Years for Seasonality Analysis
    
    # Calculate the start date based on nYears
    Start <- Sys.Date() - years(nYears)
    
    # Filter returns based on the start date
    rets_filtered <- rets_filtered[paste0(Start, "/")]
    
    if (is.null(rets_filtered) || nrow(rets_filtered) == 0) return(NULL)
    
    dds <- apply.yearly(rets_filtered, maxDrawdown)
    dds <- round(data.frame(dds,row.names = NULL)*-100,3)
    names(dds) <- c("MDD")
    
    CRT<- table.CalendarReturns(rets_filtered, digits = 1, as.perc = TRUE, geometric = T)
    CRT <- cbind(CRT,dds)
    AvgCRT <- round(as.matrix(t(apply(CRT,2,mean,na.rm=T))),3)
    rownames(AvgCRT) <- "Avg"
    CRT <- rbind(CRT,AvgCRT)
    
    
    #remove ticker col from rownames
    rownames(CRT) <- gsub(paste0(Ticker,"."), "", rownames(CRT))
    
    
    CRT
    
  }) ### End of StrategyInput ###
  
  output$Sea <-  renderDataTable({
    
    Table <- StrategyInput()
    if (is.null(Table)) return(NULL)
    
    datatable(Table, class = 'cell-border stripe',
              options = list(dom = 't', pageLength = nrow(Table),
                             columnDefs = list(list(className = 'dt-center', targets = '_all')),
                             initComplete = JS(
                               "function(settings, json) {",
                               "$(this.api().table().header()).css({'background-color': '#d1e0e0', 'color': 'black'});",
                               "}"))) %>%
      formatStyle(colnames(Table)[1:12], backgroundColor = styleInterval(0, c("#e60000","#b3ffb3"))) %>%
      formatStyle(colnames(Table)[ncol(Table)], backgroundColor = styleInterval(0, c("#ff9900","#00ff00"))) %>%
      formatStyle(" ", backgroundColor = 'white', color = 'black') %>%
      formatStyle("MDD", backgroundColor = styleInterval(0, c("#ffff99","#ffff99")))
    
    
  },
  rownames = T)
  
  
} # End of ShinyServer


# Run the app
shinyApp(ui = ui, server = server)