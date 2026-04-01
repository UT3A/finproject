// 啟動方式：
//   npm install
//   node server.js
// 瀏覽器開啟 http://localhost:3000

import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const PORT = 3000;

app.use(express.static(join(__dirname, 'public')));

// API：取得歷史股價（直接呼叫 Yahoo Finance v8 API）
app.get('/api/stock', async (req, res) => {
  const { ticker, start, end } = req.query;

  if (!ticker || !start || !end) {
    return res.status(400).json({ error: '缺少參數 ticker / start / end' });
  }

  const period1 = Math.floor(new Date(start).getTime() / 1000);
  const period2 = Math.floor(new Date(end).getTime() / 1000);
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}?interval=1d&period1=${period1}&period2=${period2}`;

  try {
    const resp = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
    });

    const json = await resp.json();
    const result = json?.chart?.result?.[0];

    if (!result) {
      const errMsg = json?.chart?.error?.description ?? '找不到資料，請確認股票代號或日期區間是否正確。';
      return res.status(404).json({ error: errMsg });
    }

    const timestamps = result.timestamp;
    const adjClose = result.indicators?.adjclose?.[0]?.adjclose;
    const close    = result.indicators?.quote?.[0]?.close;

    const prices = timestamps
      .map((ts, i) => ({
        date:  new Date(ts * 1000).toISOString().split('T')[0],
        close: (adjClose?.[i] ?? close?.[i]),
      }))
      .filter((p) => p.close != null);

    res.json(prices);
  } catch (err) {
    res.status(500).json({ error: `抓取資料時發生錯誤: ${err.message}` });
  }
});

app.listen(PORT, () => {
  console.log(`伺服器已啟動：http://localhost:${PORT}`);
});
