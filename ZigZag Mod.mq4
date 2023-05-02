//+------------------------------------------------------------------+
//|                                                       ZigZag.mq4 |
//|                              Copyright 2023, Kevin Beltran Keena |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "2023, Kevin Beltran Keena"
#property link      "http://www.mql4.com"
#property strict

#property indicator_chart_window
#property indicator_buffers 3

#property indicator_label1  "ZigZag"
#property indicator_color1  clrRed

#property indicator_label2  "Arrow Up"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreenYellow
#property indicator_width2  4

#property indicator_label3  "Arrow Dn"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  4

//---- indicator parameters
input string bullPoints = "3>1>2>0";//Bullish Setup
input string bearPoints = "0>2>1>3";//Bearish Setup
input double percentage = 5;//Price Difference in %
input bool alert = false;//Alerts
input bool email = false;//Send Email
input bool notif = false;//Send Notifications
input int InpDepth=12;     // Depth
input int InpDeviation=5;  // Deviation
input int InpBackstep=3;   // Backstep
//---- indicator buffers
double ExtZigzagBuffer[];
double ExtHighBuffer[];
double ExtLowBuffer[];
double arrowUp[];
double arrowDn[];
//--- globals
int    ExtLevel=3; // recounting's depth of extremums

int bullish[],bearish[], candle[], pivots, begin;
double point[];
datetime lastTime;

double data[],_percentage;
int x,q1,q3,size;
double X,Q1,Q3,IQR;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpBackstep>=InpDepth)
     {
      Print("Backstep cannot be greater or equal to Depth");
      return(INIT_FAILED);
     }

   string _bullPoints = bullPoints;
   string _bearPoints = bearPoints;

   int pivotsBull = 0;
   while(StringFind(_bullPoints,">",0) != -1)
     {
      ArrayResize(bullish,pivotsBull + 1,0);
      bullish[pivotsBull] = (int)StringSubstr(_bullPoints,0,StringFind(_bullPoints,">",0));
      _bullPoints = StringSubstr(_bullPoints,  StringFind(_bullPoints,">",0) + StringLen(">"),0);
      pivotsBull++;//How many commas we found in the bullPoints input
     }
   ArrayResize(bullish,pivotsBull + 1,0);
   bullish[pivotsBull] = (int)_bullPoints; //assign the last value that is left to the end of the array, because our last value doesn't have a comma after, so our String find doesn't add it


   int pivotsBear = 0;
   while(StringFind(_bearPoints,">",0) != -1)
     {
      ArrayResize(bearish,pivotsBear + 1,0);
      bearish[pivotsBear] = (int)StringSubstr(_bearPoints,0,StringFind(_bearPoints,">",0));
      _bearPoints = StringSubstr(_bearPoints,  StringFind(_bearPoints,">",0) + StringLen(">"),0);
      pivotsBear++;//How many commas we found in the bearPoints input
     }
   ArrayResize(bearish,pivotsBear + 1,0);
   bearish[pivotsBear] = (int)_bearPoints; //assign the last value that is left to the end of the array, because our last value doesn't have a comma after, so our String find doesn't add it

   pivots = MathMax(pivotsBull,pivotsBear) + 1; //Amount of commas in bullPoints/bearPoints input + 1, gives us the total points the user wants to use  (i.e. x,y,z,a,b) -> 4 commas, 5 pivots
   ArrayResize(point,pivots,0);
   ArrayResize(candle,pivots,0);

//--- 2 additional buffers
   IndicatorBuffers(5);
//---- drawing settings
   SetIndexStyle(0,DRAW_SECTION);
//---- indicator buffers
   SetIndexBuffer(0,ExtZigzagBuffer);
   SetIndexBuffer(1,arrowUp);
   SetIndexBuffer(2,arrowDn);
   SetIndexBuffer(3,ExtHighBuffer);
   SetIndexBuffer(4,ExtLowBuffer);
   SetIndexEmptyValue(0,0.0);
   SetIndexEmptyValue(1,0.0);
   SetIndexEmptyValue(2,0.0);

   PlotIndexSetString(0,PLOT_LABEL,"ZigZag");
   PlotIndexSetString(1,PLOT_LABEL,"arrowUp");
   PlotIndexSetString(2,PLOT_LABEL,"arrowDn");

   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

//---- indicator short name
   IndicatorShortName("ZigZag");
   SetIndexArrow(1,233);
   SetIndexArrow(2,234);
//---- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
  {
   int    i,limit,counterZ,whatlookfor=0;
   int    back,pos,lasthighpos=0,lastlowpos=0;
   double extremum;
   double curlow=0.0,curhigh=0.0,lasthigh=0.0,lastlow=0.0;
//--- check for history and inputs
   if(rates_total<InpDepth || InpBackstep>=InpDepth)
      return(0);
//--- first calculations
   if(prev_calculated==0)
      limit=InitializeAll();
   else
     {
      //--- find first extremum in the depth ExtLevel or 100 last bars
      i=counterZ=0;
      while(counterZ<ExtLevel && i<100)
        {
         if(ExtZigzagBuffer[i]!=0.0)
            counterZ++;
         i++;
        }
      //--- no extremum found - recounting all from begin
      if(counterZ==0)
         limit=InitializeAll();
      else
        {
         //--- set start position to found extremum position
         limit=i-1;
         //--- what kind of extremum?
         if(ExtLowBuffer[i]!=0.0)
           {
            //--- low extremum
            curlow=ExtLowBuffer[i];
            //--- will look for the next high extremum
            whatlookfor=1;
           }
         else
           {
            //--- high extremum
            curhigh=ExtHighBuffer[i];
            //--- will look for the next low extremum
            whatlookfor=-1;
           }
         //--- clear the rest data
         for(i=limit-1; i>=0; i--)
           {
            ExtZigzagBuffer[i]=0.0;
            ExtLowBuffer[i]=0.0;
            ExtHighBuffer[i]=0.0;
            arrowUp[i]=0.0;
            arrowDn[i]=0.0;
           }
        }
     }
//--- main loop
   for(i=limit; i>=0; i--)
     {
      //--- find lowest low in depth of bars
      extremum=low[iLowest(NULL,0,MODE_LOW,InpDepth,i)];
      //--- this lowest has been found previously
      if(extremum==lastlow)
         extremum=0.0;
      else
        {
         //--- new last low
         lastlow=extremum;
         //--- discard extremum if current low is too high
         if(low[i]-extremum>InpDeviation*Point)
            extremum=0.0;
         else
           {
            //--- clear previous extremums in backstep bars
            for(back=1; back<=InpBackstep; back++)
              {
               pos=i+back;
               if(ExtLowBuffer[pos]!=0 && ExtLowBuffer[pos]>extremum)
                  ExtLowBuffer[pos]=0.0;
              }
           }
        }
      //--- found extremum is current low
      if(low[i]==extremum)
         ExtLowBuffer[i]=extremum;
      else
         ExtLowBuffer[i]=0.0;
      //--- find highest high in depth of bars
      extremum=high[iHighest(NULL,0,MODE_HIGH,InpDepth,i)];
      //--- this highest has been found previously
      if(extremum==lasthigh)
         extremum=0.0;
      else
        {
         //--- new last high
         lasthigh=extremum;
         //--- discard extremum if current high is too low
         if(extremum-high[i]>InpDeviation*Point)
            extremum=0.0;
         else
           {
            //--- clear previous extremums in backstep bars
            for(back=1; back<=InpBackstep; back++)
              {
               pos=i+back;
               if(ExtHighBuffer[pos]!=0 && ExtHighBuffer[pos]<extremum)
                  ExtHighBuffer[pos]=0.0;
              }
           }
        }
      //--- found extremum is current high
      if(high[i]==extremum)
         ExtHighBuffer[i]=extremum;
      else
         ExtHighBuffer[i]=0.0;
     }
//--- final cutting
   if(whatlookfor==0)
     {
      lastlow=0.0;
      lasthigh=0.0;
     }
   else
     {
      lastlow=curlow;
      lasthigh=curhigh;
     }
   for(i=limit; i>=0; i--)
     {
      switch(whatlookfor)
        {
         case 0: // look for peak or lawn
            if(lastlow==0.0 && lasthigh==0.0)
              {
               if(ExtHighBuffer[i]!=0.0)
                 {
                  lasthigh=High[i];
                  lasthighpos=i;
                  whatlookfor=-1;
                  ExtZigzagBuffer[i]=lasthigh;
                 }
               if(ExtLowBuffer[i]!=0.0)
                 {
                  lastlow=Low[i];
                  lastlowpos=i;
                  whatlookfor=1;
                  ExtZigzagBuffer[i]=lastlow;
                 }
              }
            break;
         case 1: // look for peak
            if(ExtLowBuffer[i]!=0.0 && ExtLowBuffer[i]<lastlow && ExtHighBuffer[i]==0.0)
              {
               ExtZigzagBuffer[lastlowpos]=0.0;
               lastlowpos=i;
               lastlow=ExtLowBuffer[i];
               ExtZigzagBuffer[i]=lastlow;
              }
            if(ExtHighBuffer[i]!=0.0 && ExtLowBuffer[i]==0.0)
              {
               lasthigh=ExtHighBuffer[i];
               lasthighpos=i;
               ExtZigzagBuffer[i]=lasthigh;
               whatlookfor=-1;
              }
            break;
         case -1: // look for lawn
            if(ExtHighBuffer[i]!=0.0 && ExtHighBuffer[i]>lasthigh && ExtLowBuffer[i]==0.0)
              {
               ExtZigzagBuffer[lasthighpos]=0.0;
               lasthighpos=i;
               lasthigh=ExtHighBuffer[i];
               ExtZigzagBuffer[i]=lasthigh;
              }
            if(ExtLowBuffer[i]!=0.0 && ExtHighBuffer[i]==0.0)
              {
               lastlow=ExtLowBuffer[i];
               lastlowpos=i;
               ExtZigzagBuffer[i]=lastlow;
               whatlookfor=1;
              }
            break;
        }
     }



   if(prev_calculated==0)
     {
      begin=rates_total - 1;
      _percentage=0;
     }


   int count=0;
   if(prev_calculated>0)
     {
      for(int r = 0; r <= rates_total - 1; r++)
        {
         if(ExtZigzagBuffer[r]!=0)
            count++;
         if(count == pivots)
           {
            begin=r;
            break;
           }
        }
      _percentage=percentage;
     }




   int j = pivots - 1, q = 0;

   for(i = begin; i >= 0; i--)
      if(ExtZigzagBuffer[i]!=0)
        {
         point[j] = ExtZigzagBuffer[i];
         candle[j] = i;
         j--;


         if(j < 0)
           {
            j = pivots-1;
            i = candle[pivots - 1]; //The furthest pivot from the right side and the at the end of the loop i-- is included too!
            q = candle[0]; //The nearest pivot from the right side

            if(MathAbs(point[pivots - 1] - point[0]) / point[pivots - 1] >= percentage / 100)
              {
               for(int p = 0; p <= pivots - 1; p++)
                 {
                  if(p == pivots - 1)
                    {
                     if(prev_calculated==0)
                       {
                        ArrayResize(data,size = size+1);
                        data[size-1]=MathAbs(point[pivots - 1] - point[0]) / point[pivots - 1];
                       }


                     double atr = 0;
                     for(int a = q; a > q-30 && a > 0; a --)
                        atr = atr + iHigh(_Symbol,_Period,a) - iLow(_Symbol,_Period,a);
                     atr = atr / 30;
                     arrowUp[q]=0;
                     arrowUp[q]= low[q] - atr;
                     if(prev_calculated>0)
                        if(time[i] != lastTime)
                          {
                           lastTime=time[i];
                           if(alert==true)
                              Alert("Bullish Setup; ",_Symbol," ",(string)_Period," timeframe.");
                           if(email==true)
                              SendMail("ZigZag Mod","Bullish Setup; "+_Symbol+" "+(string)_Period+" timeframe.");
                           if(notif==true)
                              SendNotification("Bullish Setup; "+_Symbol+" "+(string)_Period+" timeframe.");
                          }
                     break;
                    }

                  if(point[bullish[p]] > point[bullish[p+1]])
                     continue;
                  else
                     break;
                 }

               for(int p = 0; p <= pivots - 1; p++)
                 {
                  if(p == pivots - 1)
                    {
                     if(prev_calculated==0)
                       {
                        ArrayResize(data,size = size+1);
                        data[size-1]=MathAbs(point[pivots - 1] - point[0]) / point[pivots - 1];
                       }


                     double atr = 0;
                     for(int a = q; a > q-30 && a > 0; a --)
                        atr = atr + iHigh(_Symbol,_Period,a) - iLow(_Symbol,_Period,a);
                     atr = atr / 30;
                     arrowDn[q]=0;
                     arrowDn[q]= high[q] + atr;
                     if(prev_calculated>0)
                        if(time[i] != lastTime)
                          {
                           lastTime=time[i];
                           if(alert==true)
                              Alert("Bearish Setup; ",_Symbol," ",(string)_Period," timeframe.");
                           if(email==true)
                              SendMail("ZigZag Mod","Bearish Setup; "+_Symbol+" "+(string)_Period+" timeframe.");
                           if(notif==true)
                              SendNotification("Bearish Setup; "+_Symbol+" "+(string)_Period+" timeframe.");
                          }
                     break;
                    }

                  if(point[bearish[p]] > point[bearish[p+1]])
                     continue;
                  else
                     break;
                 }
              }
           }
        }
//--- done
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int InitializeAll()
  {
   ArrayInitialize(ExtZigzagBuffer,0.0);
   ArrayInitialize(ExtHighBuffer,0.0);
   ArrayInitialize(ExtLowBuffer,0.0);
   ArrayInitialize(arrowUp,0.0);
   ArrayInitialize(arrowDn,0.0);
//--- first counting position
   return(Bars-InpDepth);
  }
//+------------------------------------------------------------------+
void InterquartileRange()
  {
//Sort the data in ascending order
   ArraySort(data);

//If our data set is odd
   if(ArraySize(data)%2==1)
     {
      x=ArraySize(data)/2;
      X=data[x];

      int j=0;
      for(int i=0; i<x; i++)
         j++;


      if(j%2==1)//odd
        {
         q1=x/2;
         q3=x+x/2;
         Q1=data[q1];
         Q3=data[q3];
        }

      if(j%2==0)//even
        {
         q1=(x/2);
         q3=x+x/2;
         Q1=(data[q1-1]+data[q1])/2;
         Q3=(data[q3]+data[q3+1])/2;
        }

      IQR=Q3-Q1;
     }


//If our data set is even
   if(ArraySize(data)%2==0)
     {
      x=ArraySize(data)/2;
      X=(data[x-1]+data[x])/2;

      int j=0;
      for(int i=0; i<x; i++)
         j++;


      if(j%2==1)//odd
        {
         q1=x/2;
         q3=x+x/2;
         Q1=data[q1];
         Q3=data[q3];
        }

      if(j%2==0)//even
        {
         q1=x/2;
         q3=x+x/2;
         Q1=(data[q1-1]+data[q1])/2;
         Q3=(data[q3-1]+data[q3])/2;
        }

      IQR=Q3-Q1;
     }



   int p=0;
   for(int i=0; i<ArraySize(data); i++)
      if(data[i]<Q3+1.5*IQR)
         p++;


   Comment("Data below Q3: ",p,
           "\nData Size: ",ArraySize(data),
           "\n",
           "\nQ1-3*IQR: ",DoubleToString(Q1-1.5*IQR,4),
           "\nQ1: ",DoubleToString(Q1,4),
           "\nX: ",DoubleToString(X,4),
           "\nQ3: ",DoubleToString(Q3,4),
           "\nQ3+1.5*IQR: ",DoubleToString(Q3+1.5*IQR,4),
           "\nQ3+ 3 *IQR: ",DoubleToString(Q3+3*IQR,4)/*,
           "\n",
           "\nAverage: ",DoubleToString(average,0),

           "\nMin: ",data[ArrayMinimum(data,0,WHOLE_ARRAY)],

           "\nMax: ",data[ArrayMaximum(data,0,WHOLE_ARRAY)]*/
          );
  }
//+------------------------------------------------------------------+
