part of 'problem_details.dart';

class _DefaultsValue {
  const _DefaultsValue({
    required this.link,
    required this.title,
  });

  final String link;
  final String title;
}

/// Predefined info for Problem Details response.
const _problemDetailsDefaults = <int, _DefaultsValue>{
  400: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.5.1',
    title: 'Bad Request',
  ),
  401: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7235#section-3.1',
    title: 'Unauthorized',
  ),
  403: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.5.3',
    title: 'Forbidden',
  ),
  404: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.5.4',
    title: 'Not Found',
  ),
  406: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.5.6',
    title: 'Not Acceptable',
  ),
  409: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.5.8',
    title: 'Conflict',
  ),
  415: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.5.13',
    title: 'Unsupported Media Type',
  ),
  422: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc4918#section-11.2',
    title: 'Unprocessable Entity',
  ),
  500: _DefaultsValue(
    link: 'https://www.rfc-editor.org/rfc/rfc7231#section-6.6.1',
    title: 'Internal Server Error',
  ),
};
