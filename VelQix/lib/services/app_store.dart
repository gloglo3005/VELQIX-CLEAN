// Ce fichier est conservé pour compatibilité.
// Le vrai store global est dans lib/widgets/widgets.dart (publishedPropertiesNotifier)
import '../models/models.dart';
import '../widgets/widgets.dart';

// Alias vers le vrai store pour éviter tout conflit
List<PropertyModel> get allPublishedProperties =>
    publishedProperties.cast<PropertyModel>();
