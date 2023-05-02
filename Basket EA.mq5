//+------------------------------------------------------------------+
//|                                                    Basket EA.mq5 |
//|                              Copyright 2021, Kevin Beltran Keena |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Kevin Beltran Keena"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include "Functions.mqh"
CFunctions func;

input string bullPoints = "3>1>2>0";//Bullish Setup
input string bearPoints = "0>2>1>3";//Bearish Setup
input double percentage = 5;//Price Difference in %
input int InpDepth    =12;  // Depth
input int InpDeviation=5;   // Deviation
input int InpBackstep =3;   // Back Step

input bool label=false;//Show info
input double profitThreshold=5;//Profit threshold in account currency
input double lossesThreshold=20;//Loss threshold in account currency
input int slippage=200;//Slippage
input long magicNumber=12347;//Magic number
input int takeProfit=2000;
input int stopLoss=0;



datetime closeTime;
int currencyDigits=2;
double accumulatedProfit;
int zigzagHandle;
double up[],dn[];
int arrSize=3;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
#ifdef __MQL4__
   ArrayResize(up,arrSize);
   ArrayResize(dn,arrSize);
#endif

#ifdef __MQL5__
   ArraySetAsSeries(up,true);
   ArraySetAsSeries(dn,true);
   zigzagHandle=iCustom(_Symbol,PERIOD_CURRENT,"ZigZag Mod",bullPoints,bearPoints,percentage,false,false,false,InpDepth,InpDeviation,InpBackstep);
#endif
//---
   closeTime=TimeCurrent();
   if(AccountInfoString(ACCOUNT_CURRENCY)=="JPY")
      currencyDigits=0;


   accumulatedProfit = func.accumProfit(magicNumber,closeTime);
//Close all orders if the accumulated profits is above a threshold input by the user
   if(accumulatedProfit>profitThreshold || accumulatedProfit<-lossesThreshold)
     {
      func.close(_Symbol,500,magicNumber);
      closeTime=TimeCurrent();
      accumulatedProfit=0;
     }


   Comment("Accumulated Profit: "+DoubleToString(accumulatedProfit,currencyDigits)+" "+AccountInfoString(ACCOUNT_CURRENCY),
           "\nAccount Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),currencyDigits)+" "+AccountInfoString(ACCOUNT_CURRENCY));
   if(label==false)
      Comment("");
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
#ifdef __MQL4__
   for(int i = 0; i <= arrSize - 1; i ++)
     {
      up[i]=iCustom(_Symbol,PERIOD_CURRENT,"ZigZag Mod",bullPoints,bearPoints,percentage,false,false,false,InpDepth,InpDeviation,InpBackstep,1,i);
      dn[i]=iCustom(_Symbol,PERIOD_CURRENT,"ZigZag Mod",bullPoints,bearPoints,percentage,false,false,false,InpDepth,InpDeviation,InpBackstep,2,i);
     }
#endif

#ifdef __MQL5__
   CopyBuffer(zigzagHandle,1,0,arrSize,up);
   CopyBuffer(zigzagHandle,2,0,arrSize,dn);
#endif


   if(func.newCandle(_Symbol,PERIOD_CURRENT)==true)
      //for(int i = 1; i <= arrSize - 1; i ++)
     {
      if(up[2] != 0)
         if(iHigh(_Symbol,_Period,2) < iClose(_Symbol,_Period,1))
            if(func.openBuys(_Symbol,magicNumber) < 3)
               func.trade(_Symbol,ORDER_TYPE_BUY,0.01,SymbolInfoDouble(_Symbol,SYMBOL_ASK),5000,stopLoss*_Point,takeProfit*_Point,__FILE__,magicNumber,0,clrGreen);

      if(dn[2] != 0)
         if(iLow(_Symbol,_Period,2) > iClose(_Symbol,_Period,1))
            if(func.openSells(_Symbol,magicNumber) < 3)
               func.trade(_Symbol,ORDER_TYPE_SELL,0.01,SymbolInfoDouble(_Symbol,SYMBOL_BID),5000,stopLoss*_Point,takeProfit*_Point,__FILE__,magicNumber,0,clrRed);
     }

//---
   if(label==true)
      Comment("Last close time: "+(string)closeTime,
              //"\nProfit: "+(string)profits,
              //"\nHistory profit: "+(string)historyProfit,
              "\nAccumulated Profit: "+DoubleToString(accumulatedProfit,currencyDigits)+" "+AccountInfoString(ACCOUNT_CURRENCY),
              "\nAccount Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),currencyDigits));


   accumulatedProfit = func.accumProfit(magicNumber,closeTime);
//Close all orders if the accumulated profits is above a threshold input by the user
   if(accumulatedProfit>profitThreshold || accumulatedProfit<-lossesThreshold)
     {
      func.close(_Symbol,500,magicNumber);
      closeTime=TimeCurrent();
      accumulatedProfit=0;
     }

  }
//+------------------------------------------------------------------+
