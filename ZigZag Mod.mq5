//+------------------------------------------------------------------+
//|                                                       ZigZag.mq5 |
//|                              Copyright 2023, Kevin Beltran Keena |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2023, Kevin Beltran Keena"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   3
//--- plot ZigZag
#property indicator_label1  "ZigZag"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Arrow Up"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreenYellow
#property indicator_width2  5

#property indicator_label3  "Arrow Dn"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  5

//--- input parameters
input string bullPoints = "3>1>2>0";//Bullish Setup
input string bearPoints = "0>2>1>3";//Bearish Setup
input double percentage = 5;//Price Difference in %
input bool alert = false;//Alerts
input bool email = false;//Send Email
input bool notif = false;//Send Notifications
input int InpDepth    =12;  // Depth
input int InpDeviation=5;   // Deviation
input int InpBackstep =3;   // Back Step
//--- indicator buffers
double   ZigZagBuffer[];      // main buffer
double   HighMapBuffer[];     // ZigZag high extremes (peaks)
double   LowMapBuffer[];      // ZigZag low extremes (bottoms)
double   arrowUp[];
double   arrowDn[];

int       ExtRecalc=3;         // number of last extremes for recalculation

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };

int bullish[],bearish[], candle[], pivots, begin;
double point[];
datetime lastTime;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
   string _bullPoints = bullPoints;
   string _bearPoints = bearPoints;

   int pivotsBull = 0;
   while(StringFind(_bullPoints,">",0) != -1)
     {
      ArrayResize(bullish,pivotsBull + 1,0);
      bullish[pivotsBull] = (int)StringSubstr(_bullPoints,0,StringFind(_bullPoints,">",0));
      _bullPoints = StringSubstr(_bullPoints,  StringFind(_bullPoints,">",0) + StringLen(">"),-1);
      pivotsBull++;//How many > we found in the bullPoints input
     }
   ArrayResize(bullish,pivotsBull + 1,0);
   bullish[pivotsBull] = (int)_bullPoints; //assign the last value that is left to the end of the array, because our last value doesn't have a comma after, so our String find doesn't add it


   int pivotsBear = 0;
   while(StringFind(_bearPoints,">",0) != -1)
     {
      ArrayResize(bearish,pivotsBear + 1,0);
      bearish[pivotsBear] = (int)StringSubstr(_bearPoints,0,StringFind(_bearPoints,">",0));
      _bearPoints = StringSubstr(_bearPoints,  StringFind(_bearPoints,">",0) + StringLen(">"),-1);
      pivotsBear++;//How many > we found in the bearPoints input
     }
   ArrayResize(bearish,pivotsBear + 1,0);
   bearish[pivotsBear] = (int)_bearPoints; //assign the last value that is left to the end of the array, because our last value doesn't have a comma after, so our String find doesn't add it

   pivots = MathMax(pivotsBull,pivotsBear) + 1; //Amount of commas in bullPoints/bearPoints input + 1, gives us the total points the user wants to use  (i.e. x,y,z,a,b) -> 4 commas, 5 pivots
   ArrayResize(point,pivots,0);
   ArrayResize(candle,pivots,0);

//--- indicator buffers mapping
   SetIndexBuffer(0,ZigZagBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,arrowUp,INDICATOR_DATA);
   SetIndexBuffer(2,arrowDn,INDICATOR_DATA);
   SetIndexBuffer(3,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,LowMapBuffer,INDICATOR_CALCULATIONS);

//--- set short name and digits
   string short_name="ZigZag";//StringFormat("ZigZag(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
//IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
   PlotIndexSetString(1,PLOT_LABEL,"arrowUp");
   PlotIndexSetString(2,PLOT_LABEL,"arrowDn");

   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- set an empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetInteger(1,PLOT_ARROW,233);
   PlotIndexSetInteger(2,PLOT_ARROW,234);
  }
//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total<100)
      return(0);
//---
   int    i=0;
   int    start=0,extreme_counter=0,extreme_search=Extremum;
   int    shift=0,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double curlow=0,curhigh=0,last_high=0,last_low=0;
//--- initializing
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigZagBuffer,0.0);
      ArrayInitialize(arrowUp,0.0);
      ArrayInitialize(arrowDn,0.0);
      ArrayInitialize(HighMapBuffer,0.0);
      ArrayInitialize(LowMapBuffer,0.0);

      start=InpDepth;
     }


//--- ZigZag was already calculated before
   if(prev_calculated>0)
     {
      i=rates_total-1;
      //--- searching for the third extremum from the last uncompleted bar
      while(extreme_counter<ExtRecalc && i>rates_total-100)
        {
         res=ZigZagBuffer[i];
         if(res!=0.0)
            extreme_counter++;
         i--;
        }
      i++;
      start=i;

      //--- what type of exremum we search for
      if(LowMapBuffer[i]!=0.0)
        {
         curlow=LowMapBuffer[i];
         extreme_search=Peak;
        }
      else
        {
         curhigh=HighMapBuffer[i];
         extreme_search=Bottom;
        }
      //--- clear indicator values
      for(i=start+1; i<rates_total && !IsStopped(); i++)
        {
         ZigZagBuffer[i] =0.0;
         LowMapBuffer[i] =0.0;
         HighMapBuffer[i]=0.0;
        }
     }

//--- searching for high and low extremes
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      //--- low
      val=low[Lowest(low,InpDepth,shift)];
      if(val==last_low)
         val=0.0;
      else
        {
         last_low=val;
         if((low[shift]-val)>InpDeviation*_Point)
            val=0.0;
         else
           {
            for(back=1; back<=InpBackstep; back++)
              {
               res=LowMapBuffer[shift-back];
               if((res!=0) && (res>val))
                  LowMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(low[shift]==val)
         LowMapBuffer[shift]=val;
      else
         LowMapBuffer[shift]=0.0;
      //--- high
      val=high[Highest(high,InpDepth,shift)];
      if(val==last_high)
         val=0.0;
      else
        {
         last_high=val;
         if((val-high[shift])>InpDeviation*_Point)
            val=0.0;
         else
           {
            for(back=1; back<=InpBackstep; back++)
              {
               res=HighMapBuffer[shift-back];
               if((res!=0) && (res<val))
                  HighMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(high[shift]==val)
         HighMapBuffer[shift]=val;
      else
         HighMapBuffer[shift]=0.0;
     }

//--- set last values
   if(extreme_search==0) // undefined values
     {
      last_low=0.0;
      last_high=0.0;
     }
   else
     {
      last_low=curlow;
      last_high=curhigh;
     }

//--- final selection of extreme points for ZigZag
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      res=0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low==0.0 && last_high==0.0)
              {
               if(HighMapBuffer[shift]!=0)
                 {
                  last_high=high[shift];
                  last_high_pos=shift;
                  extreme_search=Bottom;
                  ZigZagBuffer[shift]=last_high;
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0.0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=Peak;
                  ZigZagBuffer[shift]=last_low;
                  res=1;
                 }
              }
            break;
         case Peak:
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low && HighMapBuffer[shift]==0.0)
              {
               ZigZagBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=LowMapBuffer[shift];
               ZigZagBuffer[shift]=last_low;
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigZagBuffer[shift]=last_high;
               extreme_search=Bottom;
               res=1;
              }
            break;
         case Bottom:
            if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>last_high && LowMapBuffer[shift]==0.0)
              {
               ZigZagBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=HighMapBuffer[shift];
               ZigZagBuffer[shift]=last_high;
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigZagBuffer[shift]=last_low;
               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }



   if(prev_calculated==0)
      begin=0;

   int count=0;
   if(prev_calculated>0)
      for(int r = rates_total - 1; r >= 0; r--)
        {
         if(ZigZagBuffer[r]!=0)
            count++;
         if(count == pivots)
           {
            begin=r;
            break;
           }
        }






   int j = 0, q = 0;

   for(i = begin; i <= rates_total - 1; i++)
      if(ZigZagBuffer[i]!=0)
        {
         point[j] = ZigZagBuffer[i];
         candle[j] = i;
         j++;


         if(j >= pivots)
           {
            ArrayReverse(point,0,WHOLE_ARRAY);
            j=0;
            i = candle[0]; //The furthest pivot from the right side and the at the end of the loop i++ is included too!
            q = candle[pivots - 1]; //The nearest pivot from the right side



            if(MathAbs(point[pivots - 1] - point[0]) / point[pivots - 1] >= percentage / 100)
              {
               for(int p = 0; p <= pivots - 1; p++)
                 {
                  if(p == pivots - 1)
                    {
                     double atr = 0;
                     for(int a = i; a > i-30 && a > 0; a --)
                        atr = atr + high[a] - low[a];
                     atr = atr / 30;
                     arrowUp[q]=0;
                     arrowUp[q]= low[q] - atr;
                     if(prev_calculated>0)
                        if(time[i] != lastTime)
                          {
                           lastTime=time[i];
                           if(alert==true)
                              Alert("Bullish Setup; ",_Symbol," ",period(_Period)," timeframe.");
                           if(email==true)
                              SendMail("ZigZag Mod","Bullish Setup; "+_Symbol+" "+period(_Period)+" timeframe.");
                           if(notif==true)
                              SendNotification("Bullish Setup; "+_Symbol+" "+period(_Period)+" timeframe.");
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
                     double atr = 0;
                     for(int a = i; a > i-30 && a > 0; a --)
                        atr = atr + high[a] - low[a];
                     atr = atr / 30;
                     arrowDn[q]=0;
                     arrowDn[q]= high[q] + atr;
                     if(prev_calculated>0)
                        if(time[i] != lastTime)
                          {
                           lastTime=time[i];
                           if(alert==true)
                              Alert("Bearish Setup; ",_Symbol," ",period(_Period)," timeframe.");
                           if(email==true)
                              SendMail("ZigZag Mod","Bearish Setup; "+_Symbol+" "+period(_Period)+" timeframe.");
                           if(notif==true)
                              SendNotification("Bearish Setup; "+_Symbol+" "+period(_Period)+" timeframe.");
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
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|  Search for the index of the highest bar                         |
//+------------------------------------------------------------------+
int Highest(const double &array[],const int depth,const int start)
  {
   if(start<0)
      return(0);

   double max=array[start];
   int    index=start;
//--- start searching
   for(int i=start-1; i>start-depth && i>=0; i--)
     {
      if(array[i]>max)
        {
         index=i;
         max=array[i];
        }
     }
//--- return index of the highest bar
   return(index);
  }
//+------------------------------------------------------------------+
//|  Search for the index of the lowest bar                          |
//+------------------------------------------------------------------+
int Lowest(const double &array[],const int depth,const int start)
  {
   if(start<0)
      return(0);

   double min=array[start];
   int    index=start;
//--- start searching
   for(int i=start-1; i>start-depth && i>=0; i--)
     {
      if(array[i]<min)
        {
         index=i;
         min=array[i];
        }
     }
//--- return index of the lowest bar
   return(index);
  }
//+------------------------------------------------------------------+
string period(ENUM_TIMEFRAMES tf)
  {

   switch(tf)
     {
      case 1:
        { return "1 min"; break; }
      case 2:
        { return "2 min"; break; }
      case 3:
        { return "3 min"; break; }
      case 4:
        { return "4 min"; break; }
      case 5:
        { return "5 min"; break; }
      case 6:
        { return "6 min"; break; }
      case 10:
        { return "10 min"; break; }
      case 12:
        { return "12 min"; break; }
      case 15:
        { return "15 min"; break; }
      case 20:
        { return "20 min"; break; }
      case 30:
        { return "30 min"; break; }
      case 16385:
        { return "1 hour"; break; }
      case 16386:
        { return "2 hour"; break; }
      case 16387:
        { return "3 hour"; break; }
      case 16388:
        { return "4 hour"; break; }
      case 16390:
        { return "6 hour"; break; }
      case 16392:
        { return "8 hour"; break; }
      case 16396:
        { return "12 hour"; break; }
      case 16408:
        { return "Daily"; break; }
      case 32769:
        { return "Weekly"; break; }
      case 49153:
        { return "Monthly"; break; }
     }
   return "?";
  }
//+------------------------------------------------------------------+
/*void InterquartileRange()
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
           "\nQ1 - 1.5*IQR: ",DoubleToString(Q1-1.5*IQR,4),
           "\nQ1: ",DoubleToString(Q1,4),
           "\nX: ",DoubleToString(X,4),
           "\nQ3: ",DoubleToString(Q3,4),
           "\nQ3 + 1.5*IQR: ",DoubleToString(Q3+1.5*IQR,4),
           "\nQ3 + 3 *IQR: ",DoubleToString(Q3+3*IQR,4)/*,
           "\n",
           "\nAverage: ",DoubleToString(average,0),

           "\nMin: ",data[ArrayMinimum(data,0,WHOLE_ARRAY)],

           "\nMax: ",data[ArrayMaximum(data,0,WHOLE_ARRAY)]
          );
  }*/
//+------------------------------------------------------------------+
