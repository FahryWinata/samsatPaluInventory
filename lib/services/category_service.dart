import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/asset_category_model.dart';

class CategoryService {
  final _supabase = Supabase.instance.client;

  /// Get all categories
  Future<List<AssetCategory>> getAllCategories() async {
    final response = await _supabase
        .from('asset_categories')
        .select()
        .order('name', ascending: true);

    return (response as List)
        .map((json) => AssetCategory.fromMap(json))
        .toList();
  }

  /// Get category by ID
  Future<AssetCategory?> getCategoryById(int id) async {
    final response = await _supabase
        .from('asset_categories')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AssetCategory.fromMap(response);
  }

  /// Create a new category
  Future<int> createCategory(AssetCategory category) async {
    final response = await _supabase
        .from('asset_categories')
        .insert(category.toMap()..remove('id'))
        .select('id')
        .single();

    return response['id'] as int;
  }

  /// Update an existing category
  Future<void> updateCategory(AssetCategory category) async {
    if (category.id == null) {
      throw Exception('Category ID is required for update');
    }

    await _supabase
        .from('asset_categories')
        .update(category.toMap()..remove('id'))
        .eq('id', category.id!);
  }

  /// Delete a category
  Future<void> deleteCategory(int id) async {
    // First, unassign any assets from this category
    await _supabase
        .from('assets')
        .update({'category_id': null})
        .eq('category_id', id);

    // Then delete the category
    await _supabase.from('asset_categories').delete().eq('id', id);
  }

  /// Get count of assets using a category
  Future<int> getAssetCountForCategory(int categoryId) async {
    final response = await _supabase
        .from('assets')
        .select('id')
        .eq('category_id', categoryId);

    return (response as List).length;
  }

  /// Get category count
  Future<int> getCategoryCount() async {
    final response = await _supabase.from('asset_categories').select('id');
    return (response as List).length;
  }
}
