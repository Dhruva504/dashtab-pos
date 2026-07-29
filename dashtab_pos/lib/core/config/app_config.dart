class AppConfig {
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'prod');
  
  static String get baseUrl {
    switch (environment) {
      case 'staging':
        return 'https://staging-api.dashtab.com/v1';
      case 'dev':
        return 'http://localhost:5000/api';
      case 'prod':
      default:
        return 'https://dashtab-api.onrender.com/api';
    }
  }

  static const int connectTimeout = 60000;
  static const int receiveTimeout = 60000;
}
