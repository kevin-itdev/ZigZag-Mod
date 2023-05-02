//+------------------------------------------------------------------+
//|                                                    Functions.mqh |
//|                              Copyright 2023, Kevin Beltran Keena |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Kevin Beltran Keena"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFunctions
  {

private:

public:

   double            avgBuy(string symbol, long magicnumber);
   double            avgSell(string symbol, long magicnumber);
   bool              checkExpiration(datetime expiration);
   int               openBuys(string symbol, long magicnumber);
   int               openSells(string symbol, long magicnumber);
   int               openPositions(string symbol, long magicnumber);
   bool              newCandle(string symbol,ENUM_TIMEFRAMES period);
   double            accumProfit(long magicnumber, datetime closetime);


   void              breakeven(string symbol, double trailing, long magicnumber);
   void              trade(string symbol, ENUM_ORDER_TYPE type, double lots, double entry, int slip,
                           double stop, double profit, string comment, long magicnumber, datetime time, color clr);
   void              close(string symbol, int slip, long magicnumber);
   void              trailing(string symbol, double trailing, long magicnumber);
                     CFunctions();
                    ~CFunctions();


protected:

#ifdef __MQL5__
   MqlTradeRequest   request;
   MqlTradeResult    result;
#endif
   double            tickSize;
   long              digits;
   long              stopLevel;
   double            minVolume;
   double            maxVolume;
   double            volumeStep;
   int               openedBuys;
   int               openedSells;
   int               openedPositions;
   double            buyMidPrice;
   double            sellMidPrice;

   bool              CheckVolumeValue(double lots);
   void              SendOrder(string symbol, ENUM_ORDER_TYPE type, double lots, double entry, int slip, string comment, long magicnumber, datetime time, color clr);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::CFunctions()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CFunctions::checkExpiration(datetime expiration)
  {
   datetime timeNow = TimeCurrent();

   if(expiration > timeNow)
      return false;
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::~CFunctions()
  {
   Comment("");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::trade(string symbol, ENUM_ORDER_TYPE type, double lots, double entry, int slip,
                       double stop, double profit, string comment, long magicnumber, datetime time, color clr)
  {
   tickSize=SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   stopLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   minVolume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   maxVolume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   volumeStep=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);


   if(stop != 0)
      if(SymbolInfoInteger(symbol,SYMBOL_SPREAD)*tickSize > 0.5 * stop)
         stop = stop + SymbolInfoInteger(symbol,SYMBOL_SPREAD)*tickSize;

   if(lots > 0)
     {
      lots=(double)DoubleToString(lots,2);
      if(CheckVolumeValue(lots)==false)
         lots=minVolume;
      if(CheckMoneyForTrade(symbol,lots,type)==false)
         return;
     }


#ifdef __MQL5__

//--- Initialize trade request variables
   ZeroMemory(request);
   ZeroMemory(result);

   if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
     {
      request.action       =  TRADE_ACTION_DEAL;
      request.sl           =  0;
      request.tp           =  0;

      SendOrder(symbol, type, lots, entry, slip, comment, magicnumber, time, clr);

      ulong  position_ticket = 0;

      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         position_ticket = PositionGetTicket(i);// ticket of the position
         if(magicnumber == PositionGetInteger(POSITION_MAGIC) && symbol == PositionGetString(POSITION_SYMBOL))
           {
            entry=PositionGetDouble(POSITION_PRICE_OPEN);
            break;
           }
        }

      request.action          =  TRADE_ACTION_SLTP;
      if(type == ORDER_TYPE_BUY)
        {
         if(stop != 0)
            request.sl           =  entry - stop;
         if(profit != 0)
            request.tp           =  entry + profit;
         request.position     =  position_ticket;
        }
      if(type == ORDER_TYPE_SELL)
        {
         if(stop != 0)
            request.sl           =  entry + stop;
         if(profit != 0)
            request.tp           =  entry - profit;
         request.position     =  position_ticket;
        }
     }
   else
     {
      request.action          =  TRADE_ACTION_PENDING;                     // type of trade operation
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP)
        {
         if(stop != 0)
            request.sl           =  entry - stop;
         if(profit != 0)
            request.tp           =  entry + profit;
        }
      if(type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP)
        {
         if(stop != 0)
            request.sl           =  entry + stop;
         if(profit != 0)
            request.tp           =  entry - profit;
        }
      request.type_time    =  ORDER_TIME_SPECIFIED;                        // type of expiration
      request.expiration   =  time;                                        // expiration for pending orders
     }

   SendOrder(symbol, type, lots, entry, slip, comment, magicnumber, time, clr);


#endif

#ifdef __MQL4__

   int orderTicket = 0;
   double sl = 0, tp = 0;

   if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
     {
      orderTicket=OrderSend(symbol, type, lots, entry, slip, 0, 0, comment,(int) magicnumber, time, clr);
      if(orderTicket!=-1  && (stop!=0 || profit!=0))//To prevent ordermodify error 1 because we are not changing SL and TP when they are 0.
        {
         if(OrderSelect(orderTicket, SELECT_BY_TICKET)==true)
           {
            if(type==ORDER_TYPE_BUY)
              {
               sl=OrderOpenPrice()-stop;
               tp=OrderOpenPrice()+profit;
               if(!OrderModify(orderTicket,OrderOpenPrice(),stop == 0 ? 0 : sl,profit == 0 ? 0: tp,0,clr))
                  PrintFormat("OrderModify error %d",GetLastError());
              }
            if(type==ORDER_TYPE_SELL)
              {
               sl=OrderOpenPrice()+stop;
               tp=OrderOpenPrice()-profit;
               if(!OrderModify(orderTicket,OrderOpenPrice(),stop == 0 ? 0 : sl,profit == 0 ? 0: tp,0,clr))
                  PrintFormat("OrderModify error %d",GetLastError());
              }
           }
        }
     }

   if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP)
     {
      sl=entry-stop;
      tp=entry+profit;
      orderTicket=OrderSend(symbol,type,lots,entry,slip,stop == 0 ? 0 : sl,profit == 0 ? 0: tp,comment,(int)magicnumber,time,clr);
     }

   if(type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP)
     {
      sl=entry+stop;
      tp=entry-profit;
      orderTicket=OrderSend(symbol,type,lots,entry,slip,stop == 0 ? 0 : sl,profit == 0 ? 0: tp,comment,(int)magicnumber,time,clr);
     }

#endif
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::close(string symbol, int slip, long magicnumber)
  {

#ifdef __MQL5__

//--- Initialize trade request variables
   ZeroMemory(request);
   ZeroMemory(result);

   ENUM_ORDER_TYPE type = 0;
   double lots = 0, entry = 0;
   string comment;

   request.action    =  TRADE_ACTION_DEAL;

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      PositionGetTicket(i);
      if(symbol==PositionGetString(POSITION_SYMBOL) && magicnumber==PositionGetInteger(POSITION_MAGIC))
        {
         request.position  =  PositionGetInteger(POSITION_TICKET);
         type     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         lots     =  PositionGetDouble(POSITION_VOLUME);
         entry    = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol,SYMBOL_BID) : SymbolInfoDouble(symbol,SYMBOL_ASK);
         comment  =  PositionGetString(POSITION_COMMENT);
         SendOrder(symbol, type, lots, entry, slip, comment, magicnumber, NULL, NULL);
        }
     }


#endif

#ifdef __MQL4__

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
         if(OrderSymbol()==symbol && OrderMagicNumber()==magicnumber)
           {
            if(OrderType() == OP_BUY)
               if(!OrderClose(OrderTicket(),OrderLots(),SymbolInfoDouble(symbol,SYMBOL_BID),0,clrBlue))
                  PrintFormat("OrderClose error %d",GetLastError());
            if(OrderType() == OP_SELL)
               if(!OrderClose(OrderTicket(),OrderLots(),SymbolInfoDouble(symbol,SYMBOL_ASK),0,clrBlue))
                  PrintFormat("OrderClose error %d",GetLastError());
           }
     }

#endif
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::breakeven(string symbol, double trailing, long magicnumber)
  {
   openedBuys = openBuys(symbol,magicnumber);
   openedSells = openSells(symbol,magicnumber);
   digits=SymbolInfoInteger(symbol,SYMBOL_DIGITS);

#ifdef __MQL5__

//--- Initialize trade request variables
   ZeroMemory(request);
   ZeroMemory(result);


   request.action       =  TRADE_ACTION_SLTP;                  // type of trade operation
   if(openedBuys > 0)
     {
      buyMidPrice=avgBuy(symbol,magicnumber);
      double bid=SymbolInfoDouble(symbol,SYMBOL_BID);

      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong  position_ticket=PositionGetTicket(i);// ticket of the position

         if(magicnumber == PositionGetInteger(POSITION_MAGIC) && symbol == PositionGetString(POSITION_SYMBOL))
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               if(bid-(double)DoubleToString(buyMidPrice,(int)digits) > trailing)
                  if(PositionGetDouble(POSITION_PRICE_OPEN) != PositionGetDouble(POSITION_SL))
                    {
                     request.sl           =  PositionGetDouble(POSITION_PRICE_OPEN);
                     request.tp           =  PositionGetDouble(POSITION_TP);
                     request.position     =  position_ticket;
                     SendOrder(symbol, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                    }
        }

     }

   if(openedSells > 0)
     {
      sellMidPrice=avgSell(symbol,magicnumber);
      double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);



      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong  position_ticket=PositionGetTicket(i);// ticket of the position

         if(magicnumber == PositionGetInteger(POSITION_MAGIC) && symbol == PositionGetString(POSITION_SYMBOL))
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               if((double)DoubleToString(sellMidPrice,(int)digits)-ask > trailing)
                  if(PositionGetDouble(POSITION_PRICE_OPEN) != PositionGetDouble(POSITION_SL))
                    {
                     request.sl           =  PositionGetDouble(POSITION_PRICE_OPEN);
                     request.tp           =  PositionGetDouble(POSITION_TP);
                     request.position     =  position_ticket;
                     SendOrder(symbol, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                    }
        }
     }

#endif



#ifdef __MQL4__

   int i = 0;

   if(openedBuys > 0)
     {
      buyMidPrice=avgBuy(symbol,magicnumber);
      double bid = SymbolInfoDouble(symbol,SYMBOL_BID);

      for(i=OrdersTotal()-1; i>=0; i--)
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
            if(OrderMagicNumber() == magicnumber && OrderSymbol() == symbol && OrderType() == OP_BUY)
               if(bid-(double)DoubleToString(buyMidPrice,digits) > trailing)
                  if(OrderStopLoss() != OrderOpenPrice())
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,clrGreen))
                        Print(symbol+" OrderModify error ",GetLastError());
     }

   if(openedSells > 0)
     {
      sellMidPrice=avgSell(symbol,magicnumber);
      double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);

      for(i=OrdersTotal()-1; i>=0; i--)
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
            if(OrderMagicNumber() == magicnumber && OrderSymbol() == symbol && OrderType() == OP_SELL)
               if((double)DoubleToString(sellMidPrice,digits)-ask > trailing)
                  if(OrderStopLoss() != OrderOpenPrice())
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,clrRed))
                        Print(symbol+" OrderModify error ",GetLastError());
     }


#endif
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::trailing(string symbol, double trailing, long magicnumber)
  {
   openedBuys = openBuys(symbol,magicnumber);
   openedSells = openSells(symbol,magicnumber);
   digits=SymbolInfoInteger(symbol,SYMBOL_DIGITS);

#ifdef __MQL5__

//--- Initialize trade request variables
   ZeroMemory(request);
   ZeroMemory(result);


   request.action       =  TRADE_ACTION_SLTP;                  // type of trade operation
   if(openedBuys > 0)
     {
      buyMidPrice=avgBuy(symbol,magicnumber);
      double bid=SymbolInfoDouble(symbol,SYMBOL_BID);

      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong  position_ticket=PositionGetTicket(i);// ticket of the position

         if(magicnumber == PositionGetInteger(POSITION_MAGIC) && symbol == PositionGetString(POSITION_SYMBOL))
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               if(bid-(double)DoubleToString(buyMidPrice,(int)digits) > trailing)
                  if((double)DoubleToString(PositionGetDouble(POSITION_SL),(int)digits) < (double)DoubleToString(bid-trailing,(int)digits))
                    {
                     request.sl           = (double)DoubleToString(bid-trailing,(int)digits);
                     request.tp           =  PositionGetDouble(POSITION_TP);
                     request.position     =  position_ticket;
                     SendOrder(symbol, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                    }
        }

     }

   if(openedSells > 0)
     {
      sellMidPrice=avgSell(symbol,magicnumber);
      double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);



      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         ulong  position_ticket=PositionGetTicket(i);// ticket of the position

         if(magicnumber == PositionGetInteger(POSITION_MAGIC) && symbol == PositionGetString(POSITION_SYMBOL))
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               if((double)DoubleToString(sellMidPrice,(int)digits)-ask > trailing)
                  if((double)DoubleToString(PositionGetDouble(POSITION_SL),(int)digits) > (double)DoubleToString(ask+trailing,(int)digits) || (PositionGetDouble(POSITION_SL)==0))
                    {
                     request.sl           = (double)DoubleToString(ask+trailing,(int)digits);
                     request.tp           =  PositionGetDouble(POSITION_TP);
                     request.position     =  position_ticket;
                     SendOrder(symbol, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
                    }
        }
     }

#endif



#ifdef __MQL4__

   int i = 0;

   if(openedBuys > 0)
     {
      buyMidPrice=avgBuy(symbol,magicnumber);
      double bid = SymbolInfoDouble(symbol,SYMBOL_BID);

      for(i=OrdersTotal()-1; i>=0; i--)
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
            if(OrderMagicNumber() == magicnumber && OrderSymbol() == symbol && OrderType() == OP_BUY)
               if(bid-(double)DoubleToString(buyMidPrice,digits) > trailing)
                  if((double)DoubleToString(OrderStopLoss(),digits) < (double)DoubleToString(bid-trailing,digits))
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),(double)DoubleToString(bid-trailing,digits),OrderTakeProfit(),0,clrGreen))
                        Print(symbol+" OrderModify error ",GetLastError());
     }

   if(openedSells > 0)
     {
      sellMidPrice=avgSell(symbol,magicnumber);
      double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);

      for(i=OrdersTotal()-1; i>=0; i--)
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
            if(OrderMagicNumber() == magicnumber && OrderSymbol() == symbol && OrderType() == OP_SELL)
               if((double)DoubleToString(sellMidPrice,digits)-ask > trailing)
                  if((double)DoubleToString(OrderStopLoss(),digits) > (double)DoubleToString(ask+trailing,digits) || (OrderStopLoss()==0))
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),(double)DoubleToString(ask+trailing,digits),OrderTakeProfit(),0,clrRed))
                        Print(symbol+" OrderModify error ",GetLastError());
     }


#endif
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CFunctions::SendOrder(string symbol, ENUM_ORDER_TYPE type, double lots, double entry, int slip, string comment, long magicnumber, datetime time, color clr)
  {

#ifdef __MQL5__

//--- parameters of request
   request.symbol          =  symbol;              // symbol
   request.type            =  type;                // order type
   request.volume          =  lots;                // volume of lot
   request.price           =  entry;               // price for opening/closing
   request.deviation       =  slip;                // allowed deviation from the price
   request.magic           =  magicnumber;         // magicNumber of the order
   request.comment         =  comment;             // comment
   if(IsFillingTypeAllowed(symbol, SYMBOL_FILLING_FOK))
      request.type_filling =  ORDER_FILLING_FOK;
   else
      if(IsFillingTypeAllowed(symbol, SYMBOL_FILLING_IOC))
         request.type_filling = (ORDER_FILLING_IOC);
      else
         request.type_filling = (ORDER_FILLING_RETURN);

   if(!OrderSend(request,result))
     {
      PrintFormat("OrderSend error %d",GetLastError());
      return;
     }
//--- information about the operation (successfully sent the order!)
//PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
#endif

   return;
  }
//+------------------------------------------------------------------+
//| Checks if the specified filling mode is allowed on MT5           |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(string symbol, int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- Return true, if mode fill_type is allowed
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
#ifdef __MQL4__
   double free_margin=AccountFreeMarginCheck(symb,type,lots);
//-- if there is not enough money
   if(free_margin<0)
     {
      string oper=(type==OP_BUY)? "Buy":"Sell";
      Print("Not enough money for ",oper," ",lots," ",symb," Error code=",GetLastError());
      return(false);
     }
//--- checking successful
   return(true);
#endif

#ifdef __MQL5__
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double Price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      Price=mqltick.bid;
//--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
//--- call of the checking function
   if(!OrderCalcMargin(type,symb,lots,Price,margin))
     {
      //--- something went wrong, report and return false
      Print("Error in ",__FUNCTION__," code=",GetLastError());
      return(false);
     }
//--- if there are insufficient funds to perform the operation
   if(margin>free_margin)
     {
      //--- report the error and return false
      Print("Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      return(false);
     }
//--- checking successful
   return(true);
#endif
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CFunctions::CheckVolumeValue(double volume)
  {
   if(volume<minVolume)
      return(false);

   if(volume>maxVolume)
      return(false);


   int ratio=(int)MathRound(volume/volumeStep);
   if(MathAbs(ratio*volumeStep-volume)>0.0000001)
      return(false);

   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CFunctions::openBuys(string symbol, long magicnumber)
  {
   int positions=0;

#ifdef __MQL4__
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
         if(OrderMagicNumber()==magicnumber)
            if(OrderSymbol()==symbol)
               if(OrderType()==OP_BUY)
                  positions++;
     }
#endif


#ifdef __MQL5__


   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong  position_ticket=PositionGetTicket(i);// ticket of the position

      if(magicnumber==PositionGetInteger(POSITION_MAGIC) && symbol==PositionGetString(POSITION_SYMBOL))
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            positions++;
     }


#endif

   return positions;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CFunctions::openSells(string symbol, long magicnumber)
  {
   int positions=0;

#ifdef __MQL4__
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
         if(OrderMagicNumber()==magicnumber)
            if(OrderSymbol()==symbol)
               if(OrderType()==OP_SELL)
                  positions++;
     }
#endif

#ifdef __MQL5__

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong  position_ticket=PositionGetTicket(i);// ticket of the position

      if(magicnumber==PositionGetInteger(POSITION_MAGIC) && symbol==PositionGetString(POSITION_SYMBOL))
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            positions++;
     }

#endif

   return positions;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CFunctions::openPositions(string symbol, long magicnumber)
  {
   int openBuys = openBuys(symbol,magicnumber);
   int openSells = openSells(symbol,magicnumber);

   return openBuys + openSells;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CFunctions::avgBuy(string symbol, long magicnumber)
  {
   double midPrice=0;
   double midVolume=0;

#ifdef __MQL4__
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
         if(OrderMagicNumber()==magicnumber)
            if(OrderSymbol()==symbol)
               if(OrderType()==OP_BUY)
                 {
                  midPrice=midPrice+OrderOpenPrice()*OrderLots();
                  midVolume=midVolume+OrderLots();
                 }
     }
#endif


#ifdef __MQL5__

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong  position_ticket=PositionGetTicket(i);// ticket of the position

      if(magicnumber==PositionGetInteger(POSITION_MAGIC))
         if(symbol==PositionGetString(POSITION_SYMBOL))
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
              {
               midPrice=midPrice+PositionGetDouble(POSITION_PRICE_OPEN)*PositionGetDouble(POSITION_VOLUME);
               midVolume=midVolume+PositionGetDouble(POSITION_VOLUME);
              }
     }
#endif

   return (midPrice/midVolume);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CFunctions::avgSell(string symbol, long magicnumber)
  {
   double midPrice=0;
   double midVolume=0;


#ifdef __MQL4__
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
         if(OrderMagicNumber()==magicnumber)
            if(OrderSymbol()==symbol)
               if(OrderType()==OP_SELL)
                 {
                  midPrice=midPrice+OrderOpenPrice()*OrderLots();
                  midVolume=midVolume+OrderLots();
                 }
     }
#endif

#ifdef __MQL5__

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong  position_ticket=PositionGetTicket(i);// ticket of the position

      if(magicnumber==PositionGetInteger(POSITION_MAGIC))
         if(symbol==PositionGetString(POSITION_SYMBOL))
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
              {
               midPrice=midPrice+PositionGetDouble(POSITION_PRICE_OPEN)*PositionGetDouble(POSITION_VOLUME);
               midVolume=midVolume+PositionGetDouble(POSITION_VOLUME);
              }
     }
#endif

   return (midPrice/midVolume);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CFunctions::newCandle(string symbol,ENUM_TIMEFRAMES period)
  {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   long lastbar_time=SeriesInfoInteger(symbol,period,SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=(datetime)lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=(datetime)lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CFunctions::accumProfit(long magicnumber, datetime closetime)
  {
   double profits=0, historyProfit=0;

#ifdef __MQL5__
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong  positionTicket=PositionGetTicket(i);// ticket of the position

      if(positionTicket>0)
         if(PositionGetInteger(POSITION_MAGIC)==magicnumber)
            profits=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+profits;
     }


   HistorySelect(closetime,TimeCurrent());

   for(int i=HistoryDealsTotal()-1; i>=0; i--)//Careful with deposits because they can count as profits
     {
      ulong historyTicket=HistoryDealGetTicket(i);//ticket of the history deal

      if(historyTicket>0)
         if(HistoryDealGetInteger(historyTicket,DEAL_MAGIC)==magicnumber)
            historyProfit=HistoryDealGetDouble(historyTicket,DEAL_PROFIT)+HistoryDealGetDouble(historyTicket,DEAL_SWAP)+
                          +HistoryDealGetDouble(historyTicket,DEAL_FEE)+HistoryDealGetDouble(historyTicket,DEAL_COMMISSION)+historyProfit;
     }
#endif


#ifdef __MQL4__
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true)
         if(OrderMagicNumber()==magicnumber)
            profits=profits+OrderProfit()+OrderSwap()+OrderCommission();
     }


   for(i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true)
         if(OrderMagicNumber()==magicnumber)
           {
            if(OrderOpenTime()<closetime)
               break;

            historyProfit=historyProfit+OrderProfit()+OrderSwap()+OrderCommission();
           }
     }
#endif


   return historyProfit+profits;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
