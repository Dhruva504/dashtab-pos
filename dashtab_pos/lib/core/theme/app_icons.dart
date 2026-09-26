import 'package:flutter/material.dart';

/// Central icon registry mapping logical names to Material icons.
/// This mirrors the `symbol` defs in the HTML design system.
class AppIcons {
  static const flame = Icons.local_fire_department_rounded;
  static const grid = Icons.grid_view_rounded;
  static const pos = Icons.add_circle_outline_rounded;
  static const receipt = Icons.receipt_long_rounded;
  static const table = Icons.table_restaurant_rounded;
  static const chef = Icons.restaurant_rounded;
  static const book = Icons.menu_book_rounded;
  static const box = Icons.inventory_2_rounded;
  static const truck = Icons.local_shipping_rounded;
  static const heart = Icons.favorite_rounded;
  static const users = Icons.people_alt_rounded;
  static const drawer = Icons.savings_rounded;
  static const shield = Icons.shield_outlined;
  static const chart = Icons.insert_chart_outlined_rounded;
  static const sliders = Icons.tune_rounded;
  static const bell = Icons.notifications_none_rounded;
  static const search = Icons.search_rounded;
  static const sun = Icons.light_mode_rounded;
  static const moon = Icons.dark_mode_rounded;
  static const logout = Icons.logout_rounded;
  static const menu = Icons.menu_rounded;
  static const chevD = Icons.keyboard_arrow_down_rounded;
  static const plus = Icons.add_rounded;
  static const minus = Icons.remove_rounded;
  static const trash = Icons.delete_outline_rounded;
  static const pencil = Icons.edit_outlined;
  static const x = Icons.close_rounded;
  static const check = Icons.check_rounded;
  static const clock = Icons.schedule_rounded;
  static const printer = Icons.print_rounded;
  static const card = Icons.credit_card_rounded;
  static const cash = Icons.payments_rounded;
  static const wallet = Icons.account_balance_wallet_rounded;
  static const pin = Icons.location_on_outlined;
  static const user = Icons.person_outline_rounded;
  static const download = Icons.download_rounded;
  static const arrowR = Icons.arrow_forward_rounded;
  static const bag = Icons.shopping_bag_outlined;
  static const fork = Icons.restaurant_menu_rounded;
  static const alert = Icons.warning_amber_rounded;
  static const eye = Icons.visibility_outlined;
  static const info = Icons.info_outline_rounded;
  static const refresh = Icons.refresh_rounded;
  static const gift = Icons.card_giftcard_rounded;
  static const branch = Icons.account_tree_outlined;
  static const cloud = Icons.cloud_done_outlined;
  static const scale = Icons.scale_outlined;
  static const percent = Icons.percent_rounded;
  static const tax = Icons.request_quote_outlined;
  static const lock = Icons.lock_outline_rounded;
  static const key = Icons.key_rounded;
  static const store = Icons.storefront_outlined;
  static const refund = Icons.replay_rounded;
  static const split = Icons.call_split_rounded;
  static const tag = Icons.sell_outlined;
  static const star = Icons.star_rounded;
  static const history = Icons.history_rounded;
  static const database = Icons.storage_rounded;
  static const buildings = Icons.apartment_rounded;
  static const settings = Icons.settings_outlined;
  static const checkCircle = Icons.check_circle_rounded;
  static const circleOutline = Icons.radio_button_unchecked_rounded;
  static const bolt = Icons.bolt_rounded;
  static const keyboard = Icons.keyboard_outlined;
  static const undo = Icons.undo_rounded;
  static const steam = Icons.kitchen_rounded;
  static const coffee = Icons.coffee_rounded;
  static const edit = Icons.edit_rounded;
  static const map = Icons.map_outlined;
  static const checkSquare = Icons.check_box_outlined;
  static const squares = Icons.dashboard_outlined;
  static const barcode = Icons.qr_code_rounded;
  static const ticket = Icons.confirmation_number_outlined;
  static const robot = Icons.smart_toy_outlined;
  static const send = Icons.send_rounded;
  static const stop = Icons.stop_circle_outlined;
  static const play = Icons.play_circle_outline_rounded;
  static const paus = Icons.pause_circle_outline_rounded;
  static const warn = Icons.error_outline_rounded;
  static const question = Icons.help_outline_rounded;
  static const video = Icons.videocam_outlined;
  static const image = Icons.image_outlined;
  static const cafe = Icons.local_cafe_outlined;
  static const room = Icons.meeting_room_outlined;
  static const waves = Icons.waves_rounded;
  static const move = Icons.open_with_rounded;
  static const resize = Icons.open_in_full_rounded;
  static const filter = Icons.filter_alt_outlined;
  static const sortAsc = Icons.arrow_upward_rounded;
  static const sortDesc = Icons.arrow_downward_rounded;

  /// Returns the icon widget for a given name (used by dynamic views).
  static IconData byName(String name) {
    switch (name) {
      case 'flame':
        return flame;
      case 'grid':
        return grid;
      case 'pos':
        return pos;
      case 'receipt':
        return receipt;
      case 'table':
        return table;
      case 'chef':
        return chef;
      case 'book':
        return book;
      case 'box':
        return box;
      case 'truck':
        return truck;
      case 'heart':
        return heart;
      case 'users':
        return users;
      case 'drawer':
        return drawer;
      case 'shield':
        return shield;
      case 'chart':
        return chart;
      case 'sliders':
        return sliders;
      case 'bell':
        return bell;
      case 'search':
        return search;
      case 'sun':
        return sun;
      case 'moon':
        return moon;
      case 'logout':
        return logout;
      case 'menu':
        return menu;
      case 'chevD':
        return chevD;
      case 'plus':
        return plus;
      case 'minus':
        return minus;
      case 'trash':
        return trash;
      case 'pencil':
        return pencil;
      case 'x':
        return x;
      case 'check':
        return check;
      case 'clock':
        return clock;
      case 'printer':
        return printer;
      case 'card':
        return card;
      case 'cash':
        return cash;
      case 'wallet':
        return wallet;
      case 'pin':
        return pin;
      case 'user':
        return user;
      case 'download':
        return download;
      case 'arrowR':
        return arrowR;
      case 'bag':
        return bag;
      case 'fork':
        return fork;
      case 'alert':
        return alert;
      case 'eye':
        return eye;
      case 'info':
        return info;
      case 'refresh':
        return refresh;
      case 'gift':
        return gift;
      case 'branch':
        return branch;
      case 'cloud':
        return cloud;
      case 'scale':
        return scale;
      case 'percent':
        return percent;
      case 'tax':
        return tax;
      case 'lock':
        return lock;
      case 'key':
        return key;
      case 'store':
        return store;
      case 'refund':
        return refund;
      case 'split':
        return split;
      case 'tag':
        return tag;
      case 'star':
        return star;
      case 'history':
        return history;
      case 'database':
        return database;
      case 'buildings':
        return buildings;
      case 'settings':
        return settings;
      case 'checkCircle':
        return checkCircle;
      case 'bolt':
        return bolt;
      case 'keyboard':
        return keyboard;
      case 'undo':
        return undo;
      case 'steam':
        return steam;
      case 'coffee':
        return coffee;
      case 'edit':
        return edit;
      case 'map':
        return map;
      case 'checkSquare':
        return checkSquare;
      case 'barcode':
        return barcode;
      case 'ticket':
        return ticket;
      case 'send':
        return send;
      default:
        return Icons.circle_outlined;
    }
  }
}
