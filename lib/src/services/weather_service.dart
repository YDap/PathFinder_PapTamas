import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });
}

class WeatherService {
  Future<List<HourlyWeather>> fetchHourly(double lat, double lng) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(
      queryParameters: {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'hourly': 'temperature_2m,weathercode',
        'forecast_days': '1',
        'timezone': 'auto',
      },
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Weather fetch failed (${res.statusCode})');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final hourly = body['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temps = (hourly['temperature_2m'] as List).map((e) => (e as num).toDouble()).toList();
    final codes = (hourly['weathercode'] as List).map((e) => (e as num).toInt()).toList();

    return List.generate(times.length, (i) => HourlyWeather(
      time: DateTime.parse(times[i]),
      temperature: temps[i],
      weatherCode: codes[i],
    ));
  }

  static String emojiFor(int code) {
    if (code == 0)          return '☀️';
    if (code <= 2)          return '🌤️';
    if (code == 3)          return '☁️';
    if (code <= 48)         return '🌫️';
    if (code <= 55)         return '🌦️';
    if (code <= 65)         return '🌧️';
    if (code <= 77)         return '🌨️';
    if (code <= 82)         return '🌧️';
    if (code <= 84)         return '🌨️';
    if (code <= 99)         return '⛈️';
    return '🌡️';
  }

  static String labelFor(int code) {
    if (code == 0)          return 'Clear';
    if (code == 1)          return 'Mainly clear';
    if (code == 2)          return 'Partly cloudy';
    if (code == 3)          return 'Overcast';
    if (code <= 48)         return 'Fog';
    if (code <= 55)         return 'Drizzle';
    if (code <= 65)         return 'Rain';
    if (code <= 77)         return 'Snow';
    if (code <= 82)         return 'Showers';
    if (code <= 84)         return 'Snow showers';
    if (code <= 99)         return 'Thunderstorm';
    return 'Unknown';
  }
}
