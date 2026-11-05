bool isHomeWidgetExpenseLaunch(Uri? uri) =>
    uri != null &&
    uri.scheme == 'cordato' &&
    uri.host == 'widget' &&
    uri.path == '/add-expense' &&
    uri.userInfo.isEmpty &&
    !uri.hasPort &&
    uri.fragment.isEmpty &&
    uri.queryParametersAll.length == 1 &&
    uri.queryParametersAll['homeWidget']?.length == 1 &&
    uri.queryParameters['homeWidget'] == 'true';
