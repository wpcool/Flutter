import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/watermark_service.dart';

class CreateRecordPage extends StatefulWidget {
  final int? taskId;
  final String? taskTitle;
  
  const CreateRecordPage({super.key, this.taskId, this.taskTitle});

  @override
  State<CreateRecordPage> createState() => _CreateRecordPageState();
}

class _CreateRecordPageState extends State<CreateRecordPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();
  
  // Task data
  int? _taskId;
  String _taskTitle = '';
  List<dynamic> _taskItems = [];
  dynamic _selectedItem;
  int _completedCount = 0;
  int _totalCount = 0;
  int _totalRecordCount = 0;
  
  // Store data
  List<String> _storeList = [];
  List<String> _competitorList = [];
  int _selectedStoreIndex = -1;
  int _selectedCompetitorIndex = -1;
  Map<String, List<String>> _storeCompetitorMap = {};
  
  // Form data
  final Map<String, dynamic> _form = {
    'itemId': null,
    'name': '',
    'category': '',
    'specification': '',
    'price': '',
    'promoPrice': '',
    'promoInfo': '',
    'shop': '',
    'shopAddress': '',
    'remark': '',
    'longitude': null,
    'latitude': null,
  };
  
  // Photos
  List<File> _photos = [];
  
  // Loading
  bool _isLoading = false;
  bool _isLoadingData = true;
  
  // Controllers
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _specController = TextEditingController();
  final _priceController = TextEditingController();
  final _promoPriceController = TextEditingController();
  final _promoInfoController = TextEditingController();
  final _addressController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskId = widget.taskId;
    _taskTitle = widget.taskTitle ?? '';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      await _loadStoreData();
      await _loadLastStoreSelection();
      if (_taskId != null) {
        await _loadTaskItems();
        await _loadCompletionStatus();
      }
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  // 加载门店和竞店数据
  Future<void> _loadStoreData() async {
    try {
      final res = await _apiService.get('/api/competitor-stores');
      if (res is List) {
        final storeCompetitorMap = <String, List<String>>{};
        final storeList = <String>[];
        
        for (final item in res) {
          final storeName = item['store']?.toString() ?? '';
          if (storeName.isNotEmpty) {
            storeList.add(storeName);
            final competitors = (item['competitors'] as List?)?.map((c) => c.toString()).toList() ?? [];
            storeCompetitorMap[storeName] = competitors;
          }
        }
        
        setState(() {
          _storeList = storeList;
          _storeCompetitorMap = storeCompetitorMap;
        });
      }
    } catch (e) {
      print('加载门店数据失败: $e');
    }
  }

  // 加载上次保存的门店选择
  Future<void> _loadLastStoreSelection() async {
    final lastStore = _storage.getLastSelectedStore();
    final lastCompetitor = _storage.getLastSelectedCompetitor();
    
    if (lastStore != null && _storeList.isNotEmpty) {
      final storeIndex = _storeList.indexOf(lastStore);
      if (storeIndex != -1) {
        final competitorList = _storeCompetitorMap[lastStore] ?? [];
        var competitorIndex = -1;
        
        if (lastCompetitor != null) {
          competitorIndex = competitorList.indexOf(lastCompetitor);
        }
        
        setState(() {
          _selectedStoreIndex = storeIndex;
          _competitorList = competitorList;
          _selectedCompetitorIndex = competitorIndex;
          _form['shop'] = competitorIndex != -1 ? lastCompetitor : '';
        });
      }
    }
  }

  // 加载任务项
  Future<void> _loadTaskItems() async {
    try {
      final selectedTask = await _storage.getSelectedTask();
      if (selectedTask != null) {
        setState(() {
          _taskId = selectedTask['id'];
          _taskTitle = selectedTask['title'] ?? '';
          _taskItems = selectedTask['items'] ?? [];
          _totalCount = _taskItems.length;
        });
        
        // 如果只有一个商品，自动选中
        if (_taskItems.length == 1) {
          _selectTaskItem(_taskItems[0]);
        }
      }
    } catch (e) {
      print('加载任务项失败: $e');
    }
  }

  // 加载完成状态
  Future<void> _loadCompletionStatus() async {
    final userInfo = _storage.getUserInfo();
    if (userInfo == null || _taskId == null) return;
    
    try {
      final res = await _apiService.get('/api/tasks/$_taskId/completion/${userInfo.id}');
      if (res['items'] != null) {
        final itemCountMap = <int, int>{};
        for (final i in res['items']) {
          itemCountMap[i['item_id']] = i['count'] ?? 0;
        }
        
        final taskItems = _taskItems.map((item) {
          final count = itemCountMap[item['id']] ?? 0;
          return {
            ...item,
            'is_completed': count > 0,
            'record_count': count,
          };
        }).toList();
        
        final completedCount = taskItems.where((i) => (i['record_count'] ?? 0) > 0).length;
        
        setState(() {
          _taskItems = taskItems;
          _completedCount = completedCount;
          _totalRecordCount = res['total_records'] ?? 0;
        });
      }
    } catch (e) {
      print('加载完成状态失败: $e');
    }
  }

  // 门店选择变化
  void _onStoreChange(int? index) {
    if (index == null) return;
    
    final storeName = _storeList[index];
    final competitorList = _storeCompetitorMap[storeName] ?? [];
    
    setState(() {
      _selectedStoreIndex = index;
      _competitorList = competitorList;
      _selectedCompetitorIndex = -1;
      _form['shop'] = '';
    });
    
    _storage.setLastSelectedStore(storeName);
  }

  // 竞店选择变化
  void _onCompetitorChange(int? index) {
    if (index == null) return;
    
    final competitorName = _competitorList[index];
    
    setState(() {
      _selectedCompetitorIndex = index;
      _form['shop'] = competitorName;
    });
    
    _storage.setLastSelectedCompetitor(competitorName);
  }

  // 选择商品
  void _onSelectItem(dynamic item) {
    if (item['is_completed'] == true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('该商品您已经填写过了，确定要重新填写吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectTaskItem(item);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      _selectTaskItem(item);
    }
  }

  void _selectTaskItem(dynamic item) {
    setState(() {
      _selectedItem = item;
      _form['itemId'] = item['id'];
      _form['name'] = item['product_name'] ?? '';
      _form['category'] = item['category'] ?? '';
      _form['specification'] = item['product_spec'] ?? '';
    });
    
    _nameController.text = _form['name'] ?? '';
    _categoryController.text = _form['category'] ?? '';
    _specController.text = _form['specification'] ?? '';
  }

  // 表单输入
  void _onInput(String field, String value) {
    setState(() => _form[field] = value);
  }

  // 获取位置 - 使用反向地理编码获取汉字地址
  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showToast('请开启定位服务');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showToast('定位权限被拒绝');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showToast('请在设置中开启定位权限');
        return;
      }

      _showToast('正在获取位置...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true,
      );

      setState(() {
        _form['latitude'] = position.latitude;
        _form['longitude'] = position.longitude;
      });

      // 反向地理编码获取汉字地址
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // 组合地址：街道 + 子地区 + 城市
          final addressParts = <String>[];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          
          final address = addressParts.join(' ');
          setState(() {
            _form['shopAddress'] = address.isNotEmpty ? address : '${place.name}';
          });
          _addressController.text = _form['shopAddress'] ?? '';
          _showToast('定位成功: $address');
        } else {
          setState(() {
            _form['shopAddress'] = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          });
          _addressController.text = _form['shopAddress'] ?? '';
        }
      } catch (e) {
        print('反向地理编码失败: $e');
        setState(() {
          _form['shopAddress'] = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
        _addressController.text = _form['shopAddress'] ?? '';
        _showToast('位置已获取');
      }
    } catch (e) {
      _showToast('获取位置失败: $e');
    }
  }

  // 显示照片来源选择
  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              '选择照片来源',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF6366F1)),
              ),
              title: const Text('拍照'),
              subtitle: const Text('添加水印信息'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto(ImageSource.camera);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: const Text('从相册选择'),
              subtitle: const Text('不添加水印'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 拍照或从相册选择
  Future<void> _takePhoto(ImageSource source) async {
    // 检查是否已选择位置（只有拍照时才需要）
    if (source == ImageSource.camera) {
      if (_form['latitude'] == null || _form['longitude'] == null) {
        final shouldGetLocation = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('提示'),
            content: const Text('请先选择店铺位置后再拍照'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('暂不拍照'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('去选择位置'),
              ),
            ],
          ),
        );
        
        if (shouldGetLocation == true) {
          await _getLocation();
        }
        return;
      }
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      
      if (photo == null) return;
      
      // 只有拍照才添加水印
      if (source == ImageSource.camera) {
        _showToast('处理中...');
        try {
          final watermarked = await _addWatermark(File(photo.path));
          setState(() => _photos.add(watermarked));
        } catch (err) {
          print('添加水印失败: $err');
          setState(() => _photos.add(File(photo.path)));
          _showToast('水印添加失败，使用原图');
        }
      } else {
        // 相册选择不添加水印
        setState(() => _photos.add(File(photo.path)));
      }
    } catch (e) {
      _showToast('选择照片失败: $e');
    }
  }

  // 添加水印 - 使用 Flutter Canvas 支持中文
  Future<File> _addWatermark(File photoFile) async {
    // 构建门店-竞店信息
    String storeInfo = '';
    if (_selectedStoreIndex >= 0 && _selectedStoreIndex < _storeList.length) {
      storeInfo = _storeList[_selectedStoreIndex];
      if (_selectedCompetitorIndex >= 0 && _selectedCompetitorIndex < _competitorList.length) {
        storeInfo = '$storeInfo -- ${_competitorList[_selectedCompetitorIndex]}';
      }
    }
    
    final now = DateTime.now();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    
    return await WatermarkService.addWatermark(
      imageFile: photoFile,
      timeStr: timeStr,
      storeInfo: storeInfo.isNotEmpty ? storeInfo : null,
      locationStr: _form['shopAddress']?.toString(),
      lat: _form['latitude'] as double?,
      lng: _form['longitude'] as double?,
    );
  }

  // 预览照片 - 全屏查看
  void _previewPhoto(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoPreviewPage(
          photos: _photos,
          initialIndex: index,
        ),
      ),
    );
  }

  // 删除照片
  void _deletePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // 表单验证
  bool _validateForm() {
    if (_taskId == null) {
      _showToast('请先从任务页选择调研任务');
      return false;
    }
    
    if (_selectedItem == null) {
      _showToast('请选择要调研的商品');
      return false;
    }
    
    if (_form['price']?.toString().trim().isEmpty ?? true) {
      _showToast('请输入价格');
      return false;
    }
    
    if (_form['shop']?.toString().trim().isEmpty ?? true) {
      _showToast('请输入店铺名称');
      return false;
    }
    
    if (_photos.isEmpty) {
      _showToast('请至少拍摄一张商品照片');
      return false;
    }
    
    return true;
  }

  // 保存记录
  Future<void> _saveRecord() async {
    if (!_validateForm()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final userInfo = _storage.getUserInfo();
      
      // 先上传照片
      final uploadedPhotos = <String>[];
      for (final photo in _photos) {
        try {
          final uploadRes = await _apiService.uploadFile('/api/upload', photo);
          if (uploadRes['url'] != null) {
            uploadedPhotos.add(uploadRes['url']);
          }
        } catch (err) {
          print('上传照片失败: $err');
        }
      }
      
      if (uploadedPhotos.isEmpty) {
        _showToast('照片上传失败');
        setState(() => _isLoading = false);
        return;
      }

      final submitData = {
        'item_id': _selectedItem['id'],
        'surveyor_id': userInfo?.id ?? 1,
        'own_store_name': _selectedStoreIndex >= 0 ? _storeList[_selectedStoreIndex] : '',
        'store_name': _form['shop']?.toString().trim(),
        'store_address': _form['shopAddress']?.toString().trim(),
        'price': double.tryParse(_form['price']?.toString() ?? '0') ?? 0,
        'promotion_info': _form['promoInfo']?.toString().trim(),
        'remark': _form['remark']?.toString().trim(),
        'longitude': _form['longitude'],
        'latitude': _form['latitude'],
        'photos': uploadedPhotos,
      };
      
      final response = await _apiService.post('/api/records', data: submitData);
      print('提交记录响应: $response');
      
      if (response == null || (response is Map && response['error'] != null)) {
        final errorMsg = response is Map ? response['error'] : '保存失败';
        throw Exception(errorMsg);
      }
      
      setState(() => _isLoading = false);
      
      // 显示成功弹窗
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('保存成功'),
          content: Text('调研记录已保存\n记录ID: ${response['record_id'] ?? response['id'] ?? '未知'}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回任务'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续录入'),
            ),
          ],
        ),
      );
      
      if (shouldContinue == true) {
        _resetFormForNext();
        if (_taskId != null) {
          await _loadCompletionStatus();
        }
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      _showToast('保存失败: $error');
    }
  }

  // 重置表单（保留门店选择）
  void _resetFormForNext() {
    setState(() {
      _selectedItem = null;
      _photos = [];
      _form['itemId'] = null;
      _form['name'] = '';
      _form['category'] = '';
      _form['specification'] = '';
      _form['price'] = '';
      _form['promoPrice'] = '';
      _form['promoInfo'] = '';
      _form['remark'] = '';
    });
    
    _nameController.clear();
    _categoryController.clear();
    _specController.clear();
    _priceController.clear();
    _promoPriceController.clear();
    _promoInfoController.clear();
    _remarkController.clear();
    
    _showToast('请继续选择商品录入');
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _specController.dispose();
    _priceController.dispose();
    _promoPriceController.dispose();
    _promoInfoController.dispose();
    _addressController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('创建调研记录')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('创建调研记录'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_taskId == null) _buildTaskBanner(),
            if (_taskId != null) _buildCurrentTask(),
            _buildStoreSection(),
            if (_taskItems.isNotEmpty) _buildGroupedItemSelector(),
            _buildProductSection(),
            _buildPriceSection(),
            _buildRemarkSection(),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // 按品类分组的商品选择器
  Widget _buildGroupedItemSelector() {
    // 按品类分组
    final Map<String, List<dynamic>> groupedItems = {};
    for (final item in _taskItems) {
      final category = item['category'] ?? '其他';
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }

    return _buildCard(
      title: '🛒 选择商品${_totalRecordCount > 0 ? " (已调研 $_totalRecordCount 次)" : ""}',
      children: [
        const SizedBox(height: 8),
        ...groupedItems.entries.map((entry) {
          return _buildCategoryGroup(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  Widget _buildCategoryGroup(String category, List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 品类标题
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
          // 商品列表
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final isSelected = _selectedItem != null && _selectedItem['id'] == item['id'];
    final recordCount = item['record_count'] ?? 0;
    
    return InkWell(
      onTap: () => _onSelectItem(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : null,
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFE2E8F0).withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 数量徽章
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: recordCount > 0 ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$recordCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: recordCount > 0 ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 商品名和规格
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['product_name'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                    ),
                  ),
                  if (item['product_spec'] != null && item['product_spec'].toString().isNotEmpty)
                    Text(
                      item['product_spec'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
            // 选中标记
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 20),
          ],
        ),
      ),
    );
  }

  // 原有方法保持不变...
  Widget _buildTaskBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '请先选择今日调研任务，或从"任务"页面开始',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTask() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('📋', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前任务', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(_taskTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_totalRecordCount > 0)
                Text('已调研 $_totalRecordCount 次', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection() {
    return _buildCard(
      title: '🏪 店铺信息',
      children: [
        _buildLabel('选择门店', required: true),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<int>(
            value: _selectedStoreIndex >= 0 ? _selectedStoreIndex : null,
            hint: const Text('请选择门店'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: _storeList.asMap().entries.map((entry) {
              return DropdownMenuItem<int>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (val) => _onStoreChange(val),
          ),
        ),
        if (_selectedStoreIndex >= 0) ...[
          const SizedBox(height: 16),
          _buildLabel('选择竞店', required: true),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<int>(
              value: _selectedCompetitorIndex >= 0 ? _selectedCompetitorIndex : null,
              hint: const Text('请选择竞店'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: _competitorList.asMap().entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (val) => _onCompetitorChange(val),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildLabel('店铺地址'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: '点击右侧按钮选择店铺位置',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (val) => _onInput('shopAddress', val),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _getLocation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('📍', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductSection() {
    return _buildCard(
      title: '📦 商品信息',
      children: [
        _buildLabel('商品名称', required: true),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: _inputDecoration('请输入商品名称'),
          onChanged: (val) => _onInput('name', val),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('品类', required: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _categoryController,
                    decoration: _inputDecoration('如: 蔬菜'),
                    onChanged: (val) => _onInput('category', val),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('规格'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _specController,
                    decoration: _inputDecoration('如: 500g'),
                    onChanged: (val) => _onInput('specification', val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return _buildCard(
      title: '💰 价格信息',
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('价格', required: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: _inputDecoration('0.00').copyWith(
                      suffixText: '元',
                    ),
                    onChanged: (val) => _onInput('price', val),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('促销价'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promoPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: _inputDecoration('0.00').copyWith(
                      suffixText: '元',
                    ),
                    onChanged: (val) => _onInput('promoPrice', val),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLabel('促销信息'),
        const SizedBox(height: 8),
        TextField(
          controller: _promoInfoController,
          decoration: _inputDecoration('如: 买一送一、满减等'),
          onChanged: (val) => _onInput('promoInfo', val),
        ),
        const SizedBox(height: 16),
        _buildLabel('商品照片', required: true),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._photos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _previewPhoto(index),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(photo),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deletePhoto(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (_photos.length < 3)
              GestureDetector(
                onTap: _showPhotoSourceDialog,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate, size: 28, color: Color(0xFF6366F1)),
                      Text('添加', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text('${_photos.length}/3', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('拍照添加水印，相册选择不添加', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildRemarkSection() {
    return _buildCard(
      title: '📝 备注',
      children: [
        TextField(
          controller: _remarkController,
          maxLines: 3,
          maxLength: 500,
          decoration: _inputDecoration('其他补充信息...'),
          onChanged: (val) => _onInput('remark', val),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Text('保存记录', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        if (required)
          Text(
            ' *',
            style: TextStyle(color: Colors.red[400]),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}

// 图片预览页面
class PhotoPreviewPage extends StatefulWidget {
  final List<File> photos;
  final int initialIndex;

  const PhotoPreviewPage({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 图片翻页
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      widget.photos[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            // 顶部栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // 平衡布局
                  ],
                ),
              ),
            ),
            // 底部指示器（多张图片时显示）
            if (widget.photos.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.photos.asMap().entries.map((entry) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == entry.key
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
