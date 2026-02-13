import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

// API基础URL，用于拼接图片完整路径
const String _baseUrl = 'http://8.152.197.205';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _apiService = ApiService();
  final _storage = StorageService();
  List<dynamic> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final userInfo = _storage.getUserInfo();
      if (userInfo == null) {
        print('未登录，无法加载记录');
        return;
      }
      
      print('正在加载用户 ${userInfo.id} 的记录...');
      final response = await _apiService.get('/api/records?surveyor_id=${userInfo.id}');
      print('API响应: $response');
      
      if (response is List) {
        setState(() => _records = response);
        print('加载了 ${response.length} 条记录');
      } else if (response is Map && response['data'] is List) {
        setState(() => _records = response['data']);
        print('加载了 ${response['data'].length} 条记录');
      } else {
        print('未知的响应格式: ${response.runtimeType}');
      }
    } catch (e) {
      print('加载记录失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调研记录'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              color: const Color(0xFF6366F1),
              child: _records.isEmpty
                  ? const Center(child: Text('暂无记录'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return _buildRecordCard(record);
                      },
                    ),
            ),
    );
  }

  Widget _buildRecordCard(dynamic record) {
    final photos = record['photos'] as List? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRecordDetail(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record['product_name'] ?? '未知商品',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '¥${record['price'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 商品类别标签
              if (record['category'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record['category'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '自己门店: ${record['own_store_name'] ?? ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '竞店: ${record['store_name'] ?? ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    record['created_at']?.toString().substring(0, 16) ?? '',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(
                              photos[index].startsWith('http') 
                                ? photos[index] 
                                : '$_baseUrl${photos[index]}',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 显示记录详情
  void _showRecordDetail(dynamic record) {
    final photos = record['photos'] as List? ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // 拖动条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 商品名
              Text(
                record['product_name'] ?? '未知商品',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 类别
              if (record['category'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record['category'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // 价格
              _buildDetailRow('价格', '¥${record['price'] ?? 0}'),
              // 门店信息
              _buildDetailRow('自己门店', record['own_store_name'] ?? '-'),
              _buildDetailRow('竞店', record['store_name'] ?? '-'),
              // 地址
              if (record['store_address'] != null)
                _buildDetailRow('地址', record['store_address']),
              // 坐标
              if (record['latitude'] != null && record['longitude'] != null)
                _buildDetailRow('坐标', '${record['latitude']}, ${record['longitude']}'),
              // 促销信息
              if (record['promotion_info'] != null)
                _buildDetailRow('促销', record['promotion_info']),
              // 备注
              if (record['remark'] != null)
                _buildDetailRow('备注', record['remark']),
              // 时间
              _buildDetailRow('创建时间', record['created_at']?.toString().substring(0, 19) ?? '-'),
              // 图片
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  '照片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...photos.map((url) {
                  final fullUrl = url.startsWith('http') ? url : '$_baseUrl$url';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.error)),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
