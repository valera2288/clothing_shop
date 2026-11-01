-- DDL базы SQLite, созданной PocketBase по скрипту pocketbase/setup/create_schema.py.
-- Получено запросом: SELECT sql FROM sqlite_master.

CREATE TABLE `users` (`avatar` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL, `emailVisibility` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `password` TEXT DEFAULT '' NOT NULL, `tokenKey` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `verified` BOOLEAN DEFAULT FALSE NOT NULL, "role" TEXT DEFAULT '' NOT NULL, "phone" TEXT DEFAULT '' NOT NULL);

CREATE TABLE `loyalty_cards` (`created` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `number` TEXT DEFAULT '' NOT NULL, `points` NUMERIC DEFAULT 0 NOT NULL, `tier` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `addresses` (`city` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `flat` TEXT DEFAULT '' NOT NULL, `house` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `is_default` BOOLEAN DEFAULT FALSE NOT NULL, `postal_code` TEXT DEFAULT '' NOT NULL, `street` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `categories` (`created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `slug` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `brands` (`country` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `delivery_methods` (`created` TEXT DEFAULT '' NOT NULL, `days` NUMERIC DEFAULT 0 NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `products` (`active` BOOLEAN DEFAULT FALSE NOT NULL, `brand` TEXT DEFAULT '' NOT NULL, `category` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `gender` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `image_url` TEXT DEFAULT '' NOT NULL, `material` TEXT DEFAULT '' NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `sku` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `collections` (`created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `products` JSON DEFAULT '[]' NOT NULL, `season` TEXT DEFAULT '' NOT NULL, `title` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `year` NUMERIC DEFAULT 0 NOT NULL);

CREATE TABLE `product_variants` (`color` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `product` TEXT DEFAULT '' NOT NULL, `size` TEXT DEFAULT '' NOT NULL, `stock` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `orders` (`address` TEXT DEFAULT '' NOT NULL, `comment` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `delivery_method` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `ordered_at` TEXT DEFAULT '' NOT NULL, `payment` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `total` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `order_items` (`created` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `order` TEXT DEFAULT '' NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `quantity` NUMERIC DEFAULT 0 NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `variant` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `deliveries` (`carrier` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `eta` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `order` TEXT DEFAULT '' NOT NULL, `shipped_at` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `track_number` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE UNIQUE INDEX `idx_tokenKey_users` ON `users` (`tokenKey`);

CREATE UNIQUE INDEX `idx_email_users` ON `users` (`email`) WHERE `email` != '';

CREATE UNIQUE INDEX `idx_loyalty_cards_user` ON `loyalty_cards` (`user`);

CREATE UNIQUE INDEX `idx_loyalty_cards_number` ON `loyalty_cards` (`number`);

CREATE UNIQUE INDEX `idx_categories_name` ON `categories` (`name`);

CREATE UNIQUE INDEX `idx_categories_slug` ON `categories` (`slug`);

CREATE UNIQUE INDEX `idx_brands_name` ON `brands` (`name`);

CREATE UNIQUE INDEX `idx_delivery_methods_name` ON `delivery_methods` (`name`);

CREATE UNIQUE INDEX `idx_products_sku` ON `products` (`sku`);

CREATE UNIQUE INDEX `idx_collections_title` ON `collections` (`title`);

CREATE UNIQUE INDEX `idx_product_variants_product_size_color` ON `product_variants` (
  `product`,
  `size`,
  `color`
);

CREATE UNIQUE INDEX `idx_order_items_order_variant` ON `order_items` (
  `order`,
  `variant`
);

CREATE UNIQUE INDEX `idx_deliveries_order` ON `deliveries` (`order`);

