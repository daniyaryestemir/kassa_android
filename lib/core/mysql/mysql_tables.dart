const mysqlTableFields = <String, List<String>>{
  'tovary': [
    'uuid',
    'last_modified',
    'is_deleted',
    'nazvanie',
    'kolichestvo',
    'tsena_zakupki',
    'tsena_prodazhi',
    'tsena_optom',
    'category'
  ],
  'dop_shtrih_kody': [
    'uuid',
    'tovar_uuid',
    'shtrih_kod',
    'last_modified',
    'is_deleted'
  ],
  'tovar_aliases': [
    'uuid',
    'tovar_uuid',
    'alias',
    'alias_normalized',
    'last_modified',
    'is_deleted'
  ],
  'barcode_print_jobs': [
    'uuid',
    'created_at',
    'status',
    'print_name',
    'print_price',
    'note',
    'last_modified',
    'is_deleted'
  ],
  'barcode_print_queue': [
    'uuid',
    'job_uuid',
    'product_uuid',
    'barcode',
    'product_name',
    'price',
    'copies',
    'print_name',
    'print_price',
    'status',
    'created_at',
    'printed_at',
    'error_text',
    'source',
    'last_modified',
    'is_deleted'
  ],
  'clients': ['uuid', 'name', 'phone', 'points', 'last_modified', 'is_deleted'],
  'transactions': [
    'uuid',
    'client_id',
    'date',
    'amount',
    'points_earned',
    'points_spent',
    'payment_method',
    'last_modified',
    'is_deleted'
  ],
  'postupleniya': [
    'uuid',
    'kontragent',
    'data',
    'summa_postupleni',
    'summa_prodazhi',
    'summa_optom',
    'last_modified',
    'is_deleted'
  ],
  'kontragenty': ['uuid', 'name', 'last_modified', 'is_deleted'],
  'spisok_postupleniy': [
    'uuid',
    'postuplenie_uuid',
    'nazvanie',
    'kolichestvo',
    'tsena_zakupki',
    'tsena_prodazhi',
    'tsena_optom',
    'last_modified',
    'is_deleted'
  ],
  'bistrie_tovary': [
    'uuid',
    'bistri_uuid',
    'nazvanie_knopki',
    'kartinka',
    'position',
    'last_modified',
    'is_deleted'
  ],
  'cheki': [
    'uuid',
    'data',
    'tovary',
    'summa',
    'oplata',
    'skidka',
    'total_cost',
    'total_gross_profit',
    'nalichnye',
    'karta',
    'dolg',
    'klient_dolg',
    'spent_bonuses',
    'vnesennaya_summa',
    'sdacha',
    'klient_id',
    'last_modified',
    'is_deleted'
  ],
  'returned_checks': [
    'uuid',
    'original_check_id',
    'return_date',
    'items',
    'total_sum',
    'last_modified',
    'is_deleted'
  ],
  'prodazhi_history': [
    'uuid',
    'check_id',
    'sale_date',
    'amount',
    'items',
    'user_id',
    'is_return',
    'original_check_id',
    'last_modified',
    'is_deleted'
  ],
  'dolgi': [
    'uuid',
    'klient_id',
    'klient_fio',
    'phone',
    'comment',
    'cheki_uuid',
    'summa',
    'data',
    'last_modified',
    'is_deleted'
  ],
  'debt_clients': [
    'uuid',
    'name',
    'phone',
    'comment',
    'created_at',
    'last_modified',
    'is_deleted'
  ],
  'dolg_oplata': [
    'uuid',
    'klient_id',
    'summa',
    'data',
    'comment',
    'last_modified',
    'is_deleted'
  ],
  'dengi_dvizhenie': [
    'uuid',
    'data',
    'tip_operaci',
    'summa',
    'sposob',
    'opisanie',
    'istochnik',
    'last_modified',
    'is_deleted'
  ],
};

String mysqlMirrorTable(String remoteTable) => 'mysql_$remoteTable';
