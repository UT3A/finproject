# 檔案名稱要叫app.py
# 先下載套件 pip install numpy-financial /pip install multitasking /pip install streamlit pandas numpy yfinance
# terminal下 streamlit run app.py 
# pip install yfinance
# myenv\Scripts\streamlit run app.py

import streamlit as st
import pandas as pd
import numpy as np
import yfinance as yf
from datetime import date, timedelta

st.set_page_config(page_title="真實股市 定期定額計算機", layout="wide")
st.markdown("<h3 style='text-align: center; margin-top: -30px;'>真實股市：投資分析計算機</h3>", unsafe_allow_html=True)

# ==========================================
# 側邊欄：參數設定
# ==========================================
st.sidebar.header("設定參數")

# 1. 股票代號與日期輸入
ticker = st.sidebar.text_input("股票代號 (美股如 SPY, 台股如 2330.TW)", value="SPY")

default_start = date.today() - timedelta(days=365*10)
start_date = st.sidebar.date_input("起始日期", value=default_start)
end_date = st.sidebar.date_input("結束日期", value=date.today())

st.sidebar.divider()

# 2. 資金投入設定 (支援單筆 + 定期定額，也可設為 0)
initial_investment = st.sidebar.number_input("初始單筆投入 ($)", min_value=0, value=0, step=1000)
freq_option = st.sidebar.selectbox("後續投入頻率", options=["每月", "每年"], index=1)

# ★ 將 min_value 改為 0，允許投入金額等於 0
periodic_investment = st.sidebar.number_input("每次投入金額 ($)", min_value=0, value=10000, step=1000)

st.sidebar.divider()
st.sidebar.caption("資料來源：Yahoo Finance (免費 API)")

# ==========================================
# 資料獲取與處理 (透過 yfinance)
# ==========================================
with st.spinner('正在從 Yahoo Finance 抓取歷史股價...'):
    try:
        df_stock = yf.download(ticker, start=start_date, end=end_date, progress=False)
        
        if df_stock.empty:
            st.error("找不到資料，請確認股票代號或日期區間是否正確。")
            st.stop()
            
        price_col = 'Adj Close' if 'Adj Close' in df_stock.columns else 'Close'
        daily_prices = df_stock[price_col]
        
        # ==========================================
        # ★ 新增：計算資產的最大回撤 (MDD)
        # 每天的價格除以歷史最高價 - 1，找出跌幅最深的值
        # ==========================================
        roll_max = daily_prices.cummax()
        drawdown = daily_prices / roll_max - 1.0
        max_drawdown = float(drawdown.min()) # 轉為 float 確保格式正確
        
        resample_rule = 'ME' if freq_option == "每月" else 'YE'
        period_prices = daily_prices.resample(resample_rule).ffill()
        annual_returns_series = period_prices.pct_change().dropna()
        
        returns = annual_returns_series.iloc[:, 0].tolist() if isinstance(annual_returns_series, pd.DataFrame) else annual_returns_series.tolist()
        date_labels = annual_returns_series.index.strftime('%Y-%m-%d').tolist()
        
    except Exception as e:
        st.error(f"抓取資料時發生錯誤: {e}")
        st.stop()

# ==========================================
# 財富計算邏輯 (套用真實報酬率)
# ==========================================
# 將初始本金加入起始計算
current_wealth = initial_investment
cumulative_investment = initial_investment
matrix_data = []
wealth_history = [] 

for i, r in enumerate(returns):
    cumulative_investment += periodic_investment
    current_wealth = (current_wealth + periodic_investment) * (1 + r)
    
    matrix_data.append([date_labels[i], cumulative_investment, f"{r*100:.2f}%", round(current_wealth, 2)])
    wealth_history.append(current_wealth)

df = pd.DataFrame(matrix_data, columns=['日期', '累積本金', '當期報酬率', '期末財富'])
total_periods = len(returns)

if total_periods == 0:
    st.warning("選擇的日期區間太短，無法計算完整的報酬率。請將起始日期往前調。")
    st.stop()

final_wealth = current_wealth
total_cost = initial_investment + (periodic_investment * total_periods)

periods_per_year = 12 if freq_option == "每月" else 1
years_passed = total_periods / periods_per_year

# 防呆機制：如果總投入成本為 0，避免除以 0 的錯誤
if total_cost > 0:
    total_return_ratio = final_wealth / total_cost
    geometric_annual_return = (total_return_ratio) ** (1 / years_passed) - 1
else:
    geometric_annual_return = 0

asset_cagr = np.prod([1 + r for r in returns]) ** (1 / years_passed) - 1

# ==========================================
# 視覺化
# ==========================================
# ★ 將 4 個 metrics 擴充為 5 個，加入 MDD
col1, col2, col3, col4, col5 = st.columns(5)
col1.metric(label=f"總投入 ({total_periods} 期)", value=f"${total_cost:,.0f}")
col2.metric(label="最終財富", value=f"${final_wealth:,.2f}")
col3.metric(label=f"{ticker} 資產年化報酬", value=f"{asset_cagr:.2%}")
col4.metric(label="投資人年化報酬", value=f"{geometric_annual_return:.2%}")
col5.metric(label="最大回撤 (MDD)", value=f"{max_drawdown:.2%}")

col_left, col_right = st.columns([1.5, 1])

with col_left:
    chart_df = pd.DataFrame({"累積財富": wealth_history}, index=pd.to_datetime(date_labels))
    st.line_chart(chart_df, height=350)

with col_right:
    st.dataframe(df, width='stretch', height=350, hide_index=True)