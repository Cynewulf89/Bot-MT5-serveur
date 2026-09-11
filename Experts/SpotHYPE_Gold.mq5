//+------------------------------------------------------------------+
//|                                              SpotHYPE_Gold.mq5   |
//|                                  Copyright 2026, Cynewulf        |
//|                        https://github.com/Cynewulf89             |
//+------------------------------------------------------------------+
#property copyright "Cynewulf"
#property link      "https://github.com/Cynewulf89"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//--- Paramètres d'entrée
input double InpStakePerTierPct  = 0.35;   // Mise par tranche (% équité)
input int    InpMaxDcaEntries    = 2;      // Nombre max de rachats DCA
input double InpDcaStepPct       = 0.006;  // Écart rachat DCA (-0.6%)
input double InpStopLossPct      = 0.020;  // Hard Stop-Loss (-2.0%)
input double InpTrailingOffset   = 0.005;  // Activation Trailing (+0.5%)
input double InpTrailingDistance = 0.0025; // Distance Trailing (0.25%)
input int    InpRsiPeriod        = 14;     // Période RSI
input int    InpSmaPeriod        = 20;     // Période SMA
input ulong  InpMagicNumber      = 123456; // Magic Number

//--- Variables globales
int handle_rsi;
int handle_sma;
double highest_price_seen = 0.0;
bool trailing_active = false;
datetime last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   handle_rsi = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
   handle_sma = iMA(_Symbol, _Period, InpSmaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   if(handle_rsi == INVALID_HANDLE || handle_sma == INVALID_HANDLE)
   {
      Print("Erreur création des indicateurs RSI/SMA");
      return(INIT_FAILED);
   }
   
   Print("🚀 SpotHYPE Gold MT5 EA Initialisé avec succès sur ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_rsi);
   IndicatorRelease(handle_sma);
}

//+------------------------------------------------------------------+
//| Helper: Calculer la taille de lot par tranche                    |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double nominal = equity * InpStakePerTierPct;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(price <= 0 || contract_size <= 0) return 0.01;
   
   double raw_lots = nominal / (price * contract_size);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   double lots = MathFloor(raw_lots / step) * step;
   if(lots < min_lot) lots = min_lot;
   if(lots > max_lot) lots = max_lot;
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Helper: Récupérer les stats des positions ouvertes               |
//+------------------------------------------------------------------+
void GetPositionStats(int &count, double &total_volume, double &avg_price, double &first_entry_price)
{
   count = 0;
   total_volume = 0.0;
   double total_cost = 0.0;
   first_entry_price = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double vol = PositionGetDouble(POSITION_VOLUME);
         double p_open = PositionGetDouble(POSITION_PRICE_OPEN);
         count++;
         total_volume += vol;
         total_cost += vol * p_open;
         if(first_entry_price == 0.0 || PositionGetInteger(POSITION_TIME) < first_entry_price)
         {
            first_entry_price = p_open;
         }
      }
   }
   if(total_volume > 0)
      avg_price = total_cost / total_volume;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   int pos_count = 0;
   double total_vol = 0.0, avg_price = 0.0, first_price = 0.0;
   GetPositionStats(pos_count, total_vol, avg_price, first_price);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   //--- Gestion de position existante
   if(pos_count > 0)
   {
      if(bid > highest_price_seen)
         highest_price_seen = bid;
         
      // 1. Hard Stop-Loss
      if(bid <= first_price * (1.0 - InpStopLossPct))
      {
         Print("🛑 STOP-LOSS touché ! Clôture de la position globale");
         CloseAllPositions();
         highest_price_seen = 0.0;
         trailing_active = false;
         return;
      }
      
      // 2. Trailing Stop
      double gain_pct = (highest_price_seen - avg_price) / avg_price;
      if(gain_pct >= InpTrailingOffset)
      {
         trailing_active = true;
      }
      
      if(trailing_active)
      {
         double trail_sl = highest_price_seen * (1.0 - InpTrailingDistance);
         if(bid <= trail_sl)
         {
            Print("🎯 TRAILING STOP déclenché ! Clôture avec profit");
            CloseAllPositions();
            highest_price_seen = 0.0;
            trailing_active = false;
            return;
         }
      }
      
      // 3. Rachat DCA
      if(pos_count <= InpMaxDcaEntries)
      {
         double target_dca = first_price * (1.0 - pos_count * InpDcaStepPct);
         if(ask <= target_dca)
         {
            double dca_lot = CalculateLotSize();
            Print("➕ Rachat DCA #", pos_count, " au prix ", ask);
            trade.Buy(dca_lot, _Symbol, ask, 0, 0, "SpotHYPE DCA");
         }
      }
      return;
   }
   
   //--- Pas de position : Recherche de signal d'entrée sur nouvelle bougie
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(current_bar_time == last_bar_time) return;
   last_bar_time = current_bar_time;
   
   double rsi[], sma[], close[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(sma, true);
   ArraySetAsSeries(close, true);
   
   if(CopyBuffer(handle_rsi, 0, 1, 1, rsi) <= 0 ||
      CopyBuffer(handle_sma, 0, 1, 1, sma) <= 0 ||
      CopyClose(_Symbol, _Period, 1, 1, close) <= 0)
   {
      return;
   }
   
   // Signal SpotHYPE : RSI < 50 et Clôture <= SMA20
   if(rsi[0] < 50.0 && close[0] <= sma[0])
   {
      double lot = CalculateLotSize();
      Print("🟢 SIGNAL DETECTÉ sur ", _Symbol, " ! RSI: ", rsi[0], " | Lot: ", lot);
      if(trade.Buy(lot, _Symbol, ask, 0, 0, "SpotHYPE Initial"))
      {
         highest_price_seen = ask;
         trailing_active = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Fermer toutes les positions du bot                       |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         trade.PositionClose(ticket);
      }
   }
}
