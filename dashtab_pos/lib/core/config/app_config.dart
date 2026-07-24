class AppConfig {
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  
  static String get baseUrl {
    switch (environment) {
      case 'prod':
        return 'https://dashtab-api.onrender.com/api'; // Update this with your actual Render URL
      case 'staging':
        return 'https://staging-api.dashtab.com/v1';
      case 'dev':
      default:
        return 'http://localhost:5000/api';
    }
  }

  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
}
