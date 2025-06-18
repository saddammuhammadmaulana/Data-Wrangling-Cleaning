-- [1] Membuat tabel utama `stock_fundamental`
CREATE TABLE stock_fundamental (
    symbol TEXT,                                
    revenuePerShare NUMERIC,                    
    trailingPE NUMERIC,                         
    earningsQuarterlyGrowth NUMERIC,            
    previousClose NUMERIC,                      
    open NUMERIC,                               
    dayLow NUMERIC,                             
    dayHigh NUMERIC,                            
    volume BIGINT,                              
    trailingEps NUMERIC,                        
    pegRatio NUMERIC,                           
    ebitda NUMERIC,                             
    totalDebt NUMERIC,                          
    totalRevenue NUMERIC,                       
    debtToEquity NUMERIC,                       
    revenuePerShare_dup NUMERIC,                
    earningsGrowth NUMERIC,                     
    revenueGrowth NUMERIC                       
);

-- [2] Rename kolom agar konsisten dengan format penamaan yang sesuai
ALTER TABLE stock_fundamental RENAME COLUMN "revenuepershare" TO revenue_per_share;
ALTER TABLE stock_fundamental RENAME COLUMN "trailingpe" TO trailing_pe;
ALTER TABLE stock_fundamental RENAME COLUMN "earningsquarterlygrowth" TO earnings_quarterly_growth;
ALTER TABLE stock_fundamental RENAME COLUMN "trailingeps" TO trailing_eps;
ALTER TABLE stock_fundamental RENAME COLUMN "pegratio" TO peg_ratio;
ALTER TABLE stock_fundamental RENAME COLUMN "totaldebt" TO total_debt;
ALTER TABLE stock_fundamental RENAME COLUMN "totalrevenue" TO total_revenue;
ALTER TABLE stock_fundamental RENAME COLUMN "debttoequity" TO debt_to_equity;
ALTER TABLE stock_fundamental RENAME COLUMN "earningsgrowth" TO earnings_growth;
ALTER TABLE stock_fundamental RENAME COLUMN "revenuegrowth" TO revenue_growth;

-- [3] Mengubah nilai rasio pertumbuhan ke dalam satuan persen
UPDATE stock_fundamental SET earnings_quarterly_growth = earnings_quarterly_growth * 100 WHERE earnings_quarterly_growth IS NOT NULL;
UPDATE stock_fundamental SET earnings_growth = earnings_growth * 100 WHERE earnings_growth IS NOT NULL;
UPDATE stock_fundamental SET revenue_growth = revenue_growth * 100 WHERE revenue_growth IS NOT NULL;

-- [4] Mengubah format (ebitda, utang, revenue) ke dalam satuan miliar USD dan dibulatkan
UPDATE stock_fundamental SET ebitda = ROUND(ebitda / 1e9, 2) WHERE ebitda IS NOT NULL;
UPDATE stock_fundamental SET total_debt = ROUND(total_debt / 1e9, 2) WHERE total_debt IS NOT NULL;
UPDATE stock_fundamental SET total_revenue = ROUND(total_revenue / 1e9, 2) WHERE total_revenue IS NOT NULL;

-- [5] Rename kolom agar mencerminkan satuan miliar USD
ALTER TABLE stock_fundamental RENAME COLUMN ebitda TO ebitda_billionUSD;
ALTER TABLE stock_fundamental RENAME COLUMN total_debt TO total_debt_billionUSD;
ALTER TABLE stock_fundamental RENAME COLUMN total_revenue TO total_revenue_billionUSD;

-- [6] Cek dan hapus duplikat berdasarkan simbol atau kode ticker saham
WITH cte AS (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY ctid) AS rn
    FROM stock_fundamental
)
DELETE FROM stock_fundamental
WHERE ctid IN (SELECT ctid FROM cte WHERE rn > 1);

-- [7] Bersihkan data yang outlier/tidak wajar berdasarkan batas logis
UPDATE stock_fundamental SET trailing_eps = NULL WHERE ABS(trailing_eps) > 1000;
UPDATE stock_fundamental SET peg_ratio = NULL WHERE peg_ratio > 100 OR peg_ratio < -10;
UPDATE stock_fundamental SET debt_to_equity = NULL WHERE debt_to_equity > 1000;
UPDATE stock_fundamental SET earnings_growth = NULL WHERE earnings_growth < -100 OR earnings_growth > 1000;
UPDATE stock_fundamental SET revenue_growth = NULL WHERE revenue_growth < -100 OR revenue_growth > 1000;
UPDATE stock_fundamental SET earnings_quarterly_growth = NULL WHERE earnings_quarterly_growth < -100 OR earnings_quarterly_growth > 1000;

-- [8] Hapus baris yang memiliki NULL di kolom utama (incomplete rows)
DELETE FROM stock_fundamental
WHERE revenue_per_share IS NULL
   OR trailing_pe IS NULL
   OR earnings_quarterly_growth IS NULL
   OR trailing_eps IS NULL
   OR peg_ratio IS NULL
   OR ebitda_billionUSD IS NULL
   OR total_debt_billionUSD IS NULL
   OR total_revenue_billionUSD IS NULL
   OR debt_to_equity IS NULL
   OR earnings_growth IS NULL
   OR revenue_growth IS NULL;

-- [9] Tambahkan dan hitung nilai rasio PS (Price-to-Sales)
ALTER TABLE stock_fundamental ADD COLUMN ps_ratio NUMERIC;
UPDATE stock_fundamental
SET ps_ratio = trailing_pe * (trailing_eps / revenue_per_share)
WHERE trailing_pe IS NOT NULL AND trailing_eps IS NOT NULL AND revenue_per_share IS NOT NULL AND revenue_per_share != 0;

-- [10] Tambahkan dan hitung rasio Net Debt / EBITDA
ALTER TABLE stock_fundamental ADD COLUMN net_debt_to_ebitda NUMERIC;
UPDATE stock_fundamental
SET net_debt_to_ebitda = total_debt_billionUSD / ebitda_billionUSD
WHERE total_debt_billionUSD IS NOT NULL AND ebitda_billionUSD IS NOT NULL AND ebitda_billionUSD != 0;

-- [11] Tambahkan dan hitung rasio Revenue / Debt
ALTER TABLE stock_fundamental ADD COLUMN revenue_to_debt NUMERIC;
UPDATE stock_fundamental
SET revenue_to_debt = total_revenue_billionUSD / total_debt_billionUSD
WHERE total_revenue_billionUSD IS NOT NULL AND total_debt_billionUSD IS NOT NULL AND total_debt_billionUSD != 0;

-- [12] Tambahkan dan hitung Earnings Yield (%)
ALTER TABLE stock_fundamental ADD COLUMN earnings_yield_percent NUMERIC;
UPDATE stock_fundamental
SET earnings_yield_percent = (1 / trailing_pe) * 100
WHERE trailing_pe IS NOT NULL AND trailing_pe != 0;

-- [13] Tambahkan dan hitung EBITDA Margin (%)
ALTER TABLE stock_fundamental ADD COLUMN ebitda_margin_percent NUMERIC;
UPDATE stock_fundamental
SET ebitda_margin_percent = (ebitda_billionUSD / total_revenue_billionUSD) * 100
WHERE ebitda_billionUSD IS NOT NULL AND total_revenue_billionUSD IS NOT NULL AND total_revenue_billionUSD != 0;

-- [14] Cek jumlah data akhir setelah semua transformasi
SELECT COUNT(*) AS jumlah_data_setelah_drop FROM stock_fundamental;



----------------SOME QUERY INSIGHT & VALIDATION FROM THE FINAL DATA-------------

-- [15] Cek distribusi nilai trailing_pe setelah cleaning
SELECT 
  MIN(trailing_pe) AS min_pe, 
  MAX(trailing_pe) AS max_pe, 
  AVG(trailing_pe) AS avg_pe, 
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trailing_pe) AS median_pe
FROM stock_fundamental;

-- [16] Cek 10 saham dengan PEG ratio terbaik (rendah tapi tetap positif)
SELECT symbol, peg_ratio 
FROM stock_fundamental
WHERE peg_ratio > 0
ORDER BY peg_ratio ASC
LIMIT 10;

-- [17] Cek 10 perusahaan dengan EBITDA Margin tertinggi (profitabilitas operasional)
SELECT symbol, ebitda_margin_percent
FROM stock_fundamental
ORDER BY ebitda_margin_percent DESC
LIMIT 10;

-- [18] Cek 10 perusahaan dengan Net Debt to EBITDA tertinggi (leverage tinggi, risiko tinggi)
SELECT symbol, net_debt_to_ebitda
FROM stock_fundamental
ORDER BY net_debt_to_ebitda DESC
LIMIT 10;

-- [19] Cek korelasi sederhana antara earnings_yield dan ps_ratio
SELECT 
  CORR(earnings_yield_percent, ps_ratio) AS corr_ey_ps,
  CORR(earnings_yield_percent, peg_ratio) AS corr_ey_peg,
  CORR(ps_ratio, peg_ratio) AS corr_ps_peg
FROM stock_fundamental;

-- [20] Cek rata-rata revenue_growth per kuartil PS ratio
WITH ps_quartiles AS (
  SELECT *, 
         NTILE(4) OVER (ORDER BY ps_ratio) AS ps_q
  FROM stock_fundamental
)
SELECT ps_q, 
       COUNT(*) AS jumlah_perusahaan,
       ROUND(AVG(revenue_growth), 2) AS avg_revenue_growth
FROM ps_quartiles
GROUP BY ps_q
ORDER BY ps_q;

-- [21] Cek distribusi sektor jika tersedia (opsional - jika kolom sektor ada)
-- SELECT sector, COUNT(*) FROM stock_fundamental GROUP BY sector;

-- [22] Cek perusahaan dengan pertumbuhan laba tahunan (earnings_growth) negatif
SELECT symbol, earnings_growth
FROM stock_fundamental
WHERE earnings_growth < 0
ORDER BY earnings_growth ASC;

-- [23] Cek perusahaan dengan rasio utang terhadap ekuitas (debt_to_equity) ekstrem
SELECT symbol, debt_to_equity
FROM stock_fundamental
ORDER BY debt_to_equity DESC
LIMIT 10;

-- [24] Cek distribusi EPS (trailing_eps) setelah cleaning
SELECT 
  MIN(trailing_eps) AS min_eps,
  MAX(trailing_eps) AS max_eps,
  AVG(trailing_eps) AS avg_eps,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY trailing_eps) AS median_eps
FROM stock_fundamental;

-- [25] Hitung jumlah perusahaan dengan kombinasi sehat:
-- PE ratio < 25, PEG ratio < 1.5, dan Debt-to-Equity < 100
SELECT COUNT(*) AS jumlah_perusahaan_sehat
FROM stock_fundamental
WHERE trailing_pe < 25
  AND peg_ratio < 1.5
  AND debt_to_equity < 100;
