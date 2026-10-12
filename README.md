# CryptoScope — Full Flutter Crypto Research Demo

This is a Flutter-only app. It does not include a custom backend. It uses the public CoinPaprika REST API and offers mock demo data if the public API is unavailable.

## Included features from the assignment
- Coin list with price, market cap, volume, 24-hour change, rank and supply fields
- Coin details screen
- Market statistics dashboard
- Search by coin name or symbol
- Filtering for gainers and losers
- Sorting by rank, price, market cap and 24-hour change
- Persistent local watchlist using SharedPreferences
- Interactive historical price line chart using fl_chart
- Loading, API error, retry and empty states
- Switch between live API data and local mock data
- Refresh market data
- Riverpod state management and Dio HTTP client

## Requirements
- Flutter SDK / Dart 3.3 or newer
- Android Studio or VS Code with Flutter extension
- Internet connection for live API data

## Run
1. Extract this ZIP.
2. Open the extracted `crypto_research_app` folder in VS Code.
3. In terminal run:
   ```bash
   flutter pub get
   flutter run
   ```

## API used
Base URL: `https://api.coinpaprika.com/v1`

Market tickers:
`GET /tickers?quotes=USD`

Historical daily OHLCV:
`GET /coins/{coin_id}/ohlcv/historical?start=YYYY-MM-DD&end=YYYY-MM-DD`

Public API limits and historical endpoint access can change. Some historical requests may fail on a free plan; the UI handles chart errors and provides a mock-data mode for market list demos. Mock prices are illustrative and are not live data.

## Notes / honest limitations
- Market overview values are computed from the coin records returned by the endpoint, not a guaranteed global market aggregate.
- The chart uses daily historical close prices for the last seven days when the provider makes them available.
- Supply fields may be unavailable for certain assets.
- No custom server, authentication, trading, wallet connection, or transaction execution is implemented.
- Review CoinPaprika current terms, attribution requirements and rate limits before any production use.
- This is a research demo, not financial advice.
