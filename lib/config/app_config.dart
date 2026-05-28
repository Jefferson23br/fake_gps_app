/// Valores de exemplo para o repositório público.
/// Antes de rodar o app, substitua pelas suas credenciais reais.
class AppConfig {
  /// Google Cloud — Maps SDK for Android + Places API (autocomplete e detalhes).
  /// Obtenha em: https://console.cloud.google.com/apis/credentials
  static const String googleMapsApiKey =
      'AIzaSyDEMO0000000000000000000000000';

  /// Backend REST de rotas (endpoints /route, /interpolate, /simulate).
  /// Em desenvolvimento use localhost; em produção, a URL do seu servidor.
  static const String apiBaseUrl = 'http://localhost:8001';
}
