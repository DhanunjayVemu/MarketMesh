-- ================================================================
--  MULTI-COMMUNITY MARKETPLACE PLATFORM
--  MySQL Schema — DBMS Course Project
--  Based on validated ER diagram | InnoDB | UTF-8mb4 | 3NF
-- ================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET time_zone = '+05:30';

CREATE DATABASE IF NOT EXISTS marketplace_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE marketplace_db;

-- ================================================================
-- SECTION 1 — TABLE DEFINITIONS
-- ================================================================

-- ----------------------------------------------------------------
-- 1.1  USER
-- ----------------------------------------------------------------
CREATE TABLE user (
    user_id       INT            NOT NULL AUTO_INCREMENT,
    username      VARCHAR(50)    NOT NULL,
    email         VARCHAR(100)   NOT NULL,
    password_hash VARCHAR(255)   NOT NULL,
    full_name     VARCHAR(100)   NOT NULL,
    bio           TEXT,
    avatar_url    VARCHAR(500),
    avg_rating    DECIMAL(3,2)   NOT NULL DEFAULT 0.00,
    total_reviews INT            NOT NULL DEFAULT 0,
    status        ENUM('active','suspended','deleted')
                                 NOT NULL DEFAULT 'active',
    created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_active   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_user        PRIMARY KEY (user_id),
    CONSTRAINT uq_username    UNIQUE (username),
    CONSTRAINT uq_email       UNIQUE (email),
    CONSTRAINT chk_avg_rating CHECK (avg_rating BETWEEN 0.00 AND 5.00),
    CONSTRAINT chk_tot_rev    CHECK (total_reviews >= 0)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.2  COMMUNITY
-- ----------------------------------------------------------------
CREATE TABLE community (
    community_id   INT           NOT NULL AUTO_INCREMENT,
    name           VARCHAR(100)  NOT NULL,
    description    TEXT,
    invite_code    VARCHAR(20)   NOT NULL,
    icon_url       VARCHAR(500),
    banner_url     VARCHAR(500),
    visibility     ENUM('public','private','invite_only')
                                 NOT NULL DEFAULT 'public',
    created_by     INT           NOT NULL,
    total_members  INT           NOT NULL DEFAULT 1,   -- maintained by trigger
    total_listings INT           NOT NULL DEFAULT 0,   -- maintained by trigger
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_community      PRIMARY KEY (community_id),
    CONSTRAINT uq_invite_code    UNIQUE (invite_code),
    CONSTRAINT fk_comm_creator   FOREIGN KEY (created_by)
        REFERENCES user(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_total_members CHECK (total_members >= 0),
    CONSTRAINT chk_total_list    CHECK (total_listings >= 0)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.3  MEMBERSHIP  (M:N associative — user ↔ community)
-- ----------------------------------------------------------------
CREATE TABLE membership (
    membership_id INT       NOT NULL AUTO_INCREMENT,
    user_id       INT       NOT NULL,
    community_id  INT       NOT NULL,
    role          ENUM('owner','admin','moderator','member')
                            NOT NULL DEFAULT 'member',
    joined_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    is_banned     BOOLEAN   NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_membership    PRIMARY KEY (membership_id),
    CONSTRAINT uq_user_comm     UNIQUE (user_id, community_id),  -- prevents duplicates
    CONSTRAINT fk_mem_user      FOREIGN KEY (user_id)
        REFERENCES user(user_id)      ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mem_community FOREIGN KEY (community_id)
        REFERENCES community(community_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.4  CATEGORY  (self-referencing for hierarchy)
-- ----------------------------------------------------------------
CREATE TABLE category (
    category_id        INT          NOT NULL AUTO_INCREMENT,
    name               VARCHAR(100) NOT NULL,
    icon               VARCHAR(100),
    community_id       INT,           -- NULL = global category
    parent_category_id INT,           -- NULL = root
    CONSTRAINT pk_category        PRIMARY KEY (category_id),
    CONSTRAINT fk_cat_community   FOREIGN KEY (community_id)
        REFERENCES community(community_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cat_parent      FOREIGN KEY (parent_category_id)
        REFERENCES category(category_id)   ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.5  LISTING
-- ----------------------------------------------------------------
CREATE TABLE listing (
    listing_id   INT              NOT NULL AUTO_INCREMENT,
    seller_id    INT              NOT NULL,
    community_id INT              NOT NULL,
    category_id  INT,
    title        VARCHAR(200)     NOT NULL,
    description  TEXT,
    price        DECIMAL(10,2)    NOT NULL,
    price_type   ENUM('fixed','negotiable','free')
                                  NOT NULL DEFAULT 'fixed',
    quantity     INT              NOT NULL DEFAULT 1,
        `condition`  ENUM('new','like_new','good','fair','poor')
                                  NOT NULL DEFAULT 'good',
    status       ENUM('active','reserved','sold','deleted')
                                  NOT NULL DEFAULT 'active',
    location     VARCHAR(200),
    view_count   INT              NOT NULL DEFAULT 0,
    created_at   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                           ON UPDATE CURRENT_TIMESTAMP,
    sold_at      TIMESTAMP,
    CONSTRAINT pk_listing          PRIMARY KEY (listing_id),
    CONSTRAINT fk_list_seller      FOREIGN KEY (seller_id)
        REFERENCES user(user_id)       ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_list_community   FOREIGN KEY (community_id)
        REFERENCES community(community_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_list_category    FOREIGN KEY (category_id)
        REFERENCES category(category_id)   ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_price           CHECK (price >= 0),
    CONSTRAINT chk_quantity        CHECK (quantity >= 0),
    CONSTRAINT chk_view_count      CHECK (view_count >= 0)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.6  LISTING_IMAGE  (weak entity — depends on listing)
-- ----------------------------------------------------------------
CREATE TABLE listing_image (
    image_id    INT          NOT NULL AUTO_INCREMENT,
    listing_id  INT          NOT NULL,
    image_url   VARCHAR(500) NOT NULL,
    sort_order  INT          NOT NULL DEFAULT 0,
    is_primary  BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_listing_image  PRIMARY KEY (image_id),
    CONSTRAINT fk_img_listing    FOREIGN KEY (listing_id)
        REFERENCES listing(listing_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.7  TAG
-- ----------------------------------------------------------------
CREATE TABLE tag (
    tag_id  INT         NOT NULL AUTO_INCREMENT,
    name    VARCHAR(50) NOT NULL,
    CONSTRAINT pk_tag   PRIMARY KEY (tag_id),
    CONSTRAINT uq_tag   UNIQUE (name)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.8  LISTING_TAG  (M:N junction — listing ↔ tag)
-- ----------------------------------------------------------------
CREATE TABLE listing_tag (
    listing_id INT NOT NULL,
    tag_id     INT NOT NULL,
    CONSTRAINT pk_listing_tag  PRIMARY KEY (listing_id, tag_id),
    CONSTRAINT fk_lt_listing   FOREIGN KEY (listing_id)
        REFERENCES listing(listing_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_lt_tag       FOREIGN KEY (tag_id)
        REFERENCES tag(tag_id)         ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
CREATE TABLE transaction (
    transaction_id   INT             NOT NULL AUTO_INCREMENT,
    listing_id       INT             NOT NULL,
    buyer_id         INT             NOT NULL,
    seller_id        INT             NOT NULL,
    amount           DECIMAL(10,2)   NOT NULL,
    status           ENUM('pending','completed','cancelled','disputed')
                                     NOT NULL DEFAULT 'pending',
    meetup_location  VARCHAR(200),
    created_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at     TIMESTAMP,
    CONSTRAINT pk_transaction      PRIMARY KEY (transaction_id),
    CONSTRAINT fk_txn_listing      FOREIGN KEY (listing_id)
        REFERENCES listing(listing_id)  ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_buyer        FOREIGN KEY (buyer_id)
        REFERENCES user(user_id)        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_seller       FOREIGN KEY (seller_id)
        REFERENCES user(user_id)        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_txn_amount      CHECK (amount >= 0),
        REFERENCES review(review_id)    ON DELETE SET NULL ON UPDATE CASCADE,
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.10  REVIEW
--   UNIQUE(transaction_id, reviewer_id) enforces at most 2 reviews
--   per transaction (one from each party)
-- ----------------------------------------------------------------
CREATE TABLE review (
    review_id      INT     NOT NULL AUTO_INCREMENT,
    transaction_id INT     NOT NULL,
    reviewer_id    INT     NOT NULL,
    reviewee_id    INT     NOT NULL,
    rating         TINYINT NOT NULL,
    comment        TEXT,
    review_type    ENUM('buyer_to_seller','seller_to_buyer')
                           NOT NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_review            PRIMARY KEY (review_id),
    CONSTRAINT uq_txn_reviewer      UNIQUE (transaction_id, reviewer_id),
    CONSTRAINT fk_rev_transaction   FOREIGN KEY (transaction_id)
        REFERENCES transaction(transaction_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rev_reviewer      FOREIGN KEY (reviewer_id)
        REFERENCES user(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rev_reviewee      FOREIGN KEY (reviewee_id)
        REFERENCES user(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_rating           CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_no_self_review   CHECK (reviewer_id <> reviewee_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.11  CHANNEL
-- ----------------------------------------------------------------
CREATE TABLE channel (
    channel_id   INT          NOT NULL AUTO_INCREMENT,
    community_id INT          NOT NULL,
    name         VARCHAR(100) NOT NULL,
    channel_type ENUM('general','listings','announcements','text')
                              NOT NULL DEFAULT 'general',
    created_by   INT          NOT NULL,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_channel        PRIMARY KEY (channel_id),
    CONSTRAINT fk_chan_community  FOREIGN KEY (community_id)
        REFERENCES community(community_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chan_creator    FOREIGN KEY (created_by)
        REFERENCES user(user_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.12  MESSAGE  (threaded via reply_to self-FK)
-- ----------------------------------------------------------------
CREATE TABLE message (
    message_id INT       NOT NULL AUTO_INCREMENT,
    channel_id INT       NOT NULL,
    sender_id  INT       NOT NULL,
    content    TEXT      NOT NULL,
    reply_to   INT,
    is_edited  BOOLEAN   NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN   NOT NULL DEFAULT FALSE,
    sent_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_message      PRIMARY KEY (message_id),
    CONSTRAINT fk_msg_channel  FOREIGN KEY (channel_id)
        REFERENCES channel(channel_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_msg_sender   FOREIGN KEY (sender_id)
        REFERENCES user(user_id)       ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_msg_reply    FOREIGN KEY (reply_to)
        REFERENCES message(message_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.13  DIRECT_MESSAGE
-- ----------------------------------------------------------------
CREATE TABLE direct_message (
    dm_id       INT       NOT NULL AUTO_INCREMENT,
    sender_id   INT       NOT NULL,
    receiver_id INT       NOT NULL,
    content     TEXT      NOT NULL,
    is_read     BOOLEAN   NOT NULL DEFAULT FALSE,
    sent_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_dm            PRIMARY KEY (dm_id),
    CONSTRAINT fk_dm_sender     FOREIGN KEY (sender_id)
        REFERENCES user(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_dm_receiver   FOREIGN KEY (receiver_id)
        REFERENCES user(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_dm_parties   CHECK (sender_id <> receiver_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.14  REPORT
-- ----------------------------------------------------------------
CREATE TABLE report (
    report_id   INT       NOT NULL AUTO_INCREMENT,
    reporter_id INT       NOT NULL,
    listing_id  INT       NOT NULL,
    reason      ENUM('spam','fraud','prohibited_item','wrong_category','other')
                          NOT NULL,
    description TEXT,
    status      ENUM('open','under_review','resolved','dismissed')
                          NOT NULL DEFAULT 'open',
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_report        PRIMARY KEY (report_id),
    CONSTRAINT fk_rep_reporter  FOREIGN KEY (reporter_id)
        REFERENCES user(user_id)    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rep_listing   FOREIGN KEY (listing_id)
        REFERENCES listing(listing_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.15  NOTIFICATION
-- ----------------------------------------------------------------
CREATE TABLE notification (
    notification_id INT       NOT NULL AUTO_INCREMENT,
    user_id         INT       NOT NULL,
    type            ENUM('new_message','listing_sold','new_review',
                         'price_drop','community_invite','report_update')
                              NOT NULL,
    content         TEXT      NOT NULL,
    ref_id          INT,       -- polymorphic: points to relevant entity id
    is_read         BOOLEAN   NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_notification  PRIMARY KEY (notification_id),
    CONSTRAINT fk_notif_user    FOREIGN KEY (user_id)
        REFERENCES user(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------
-- 1.16  SAVED_LISTING  (M:N — added: not in original ER, fills gap)
-- ----------------------------------------------------------------
CREATE TABLE saved_listing (
    user_id    INT       NOT NULL,
    listing_id INT       NOT NULL,
    saved_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_saved          PRIMARY KEY (user_id, listing_id),
    CONSTRAINT fk_saved_user     FOREIGN KEY (user_id)
        REFERENCES user(user_id)        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_saved_listing  FOREIGN KEY (listing_id)
        REFERENCES listing(listing_id)  ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ================================================================
-- SECTION 2 — INDEXES
-- ================================================================

CREATE INDEX idx_listing_community  ON listing(community_id);
CREATE INDEX idx_listing_seller     ON listing(seller_id);
CREATE INDEX idx_listing_status     ON listing(status);
CREATE INDEX idx_listing_category   ON listing(category_id);
CREATE INDEX idx_listing_price      ON listing(price);
CREATE INDEX idx_membership_user    ON membership(user_id);
CREATE INDEX idx_membership_comm    ON membership(community_id);
CREATE INDEX idx_txn_buyer          ON transaction(buyer_id);
CREATE INDEX idx_txn_seller         ON `transaction`(seller_id);
INSERT INTO listing (seller_id,community_id,category_id,title,description,price,price_type,`condition`,location) VALUES
CREATE INDEX idx_review_reviewee    ON review(reviewee_id);
CREATE INDEX idx_message_channel    ON message(channel_id);
CREATE INDEX idx_dm_receiver        ON direct_message(receiver_id);
CREATE INDEX idx_notif_user_read    ON notification(user_id, is_read);

-- ================================================================
-- SECTION 3 — SAMPLE DATA
-- ================================================================

-- 3.1  Users
INSERT INTO user (username, email, password_hash, full_name, bio) VALUES
  ('alice_k',     'alice@mail.com',   SHA2('pass123',256), 'Alice Kumar',    'Furniture & home goods'),
  ('bob_s',       'bob@mail.com',     SHA2('pass123',256), 'Bob Sharma',     'Book trader @ NIT'),
  ('carol_n',     'carol@mail.com',   SHA2('pass123',256), 'Carol Nair',     'Pro photographer'),
  ('dev_p',       'dev@mail.com',     SHA2('pass123',256), 'Dev Patel',      'Electronics reseller'),
  ('eve_m',       'eve@mail.com',     SHA2('pass123',256), 'Eve Menon',      'Handmade crafts'),
  ('frank_r',     'frank@mail.com',   SHA2('pass123',256), 'Frank Rao',      'Fitness equipment'),
  ('grace_v',     'grace@mail.com',   SHA2('pass123',256), 'Grace Verma',    'Clothing & fashion'),
  ('harry_p',     'harry@mail.com',   SHA2('pass123',256), 'Harry Pillai',   'Vintage collectibles');

-- 3.2  Communities
INSERT INTO community (name, description, invite_code, visibility, created_by) VALUES
  ('Apartment Block 7',     'Buy/sell within our apartment complex',       'APT7-001',  'public',       1),
  ('NIT Surathkal Market',  'Student marketplace — books, gadgets, more',  'NITS-002',  'public',       2),
  ('Photography Collective','Camera gear, prints, and session bookings',   'PHOT-003',  'public',       3),
  ('Tech Swap',             'Electronics and gadgets exchange',            'TECH-004',  'public',       4),
  ('Fitness Hub',           'Used fitness equipment at fair prices',       'FIT-005',   'invite_only',  6);

-- 3.3  Memberships
INSERT INTO membership (user_id, community_id, role) VALUES
  -- Apt Block 7
  (1,1,'owner'),(2,1,'member'),(3,1,'member'),(5,1,'member'),
  -- NIT Market
  (2,2,'owner'),(1,2,'member'),(4,2,'member'),(7,2,'member'),
  -- Photography
  (3,3,'owner'),(1,3,'member'),(4,3,'member'),
  -- Tech Swap
  (4,4,'owner'),(2,4,'member'),(6,4,'member'),
  -- Fitness Hub
  (6,5,'owner'),(1,5,'member'),(8,5,'member');

-- NOTE: total_members is set by trigger on INSERT to membership.
-- For sample data loaded without triggers active, patch manually:
UPDATE community SET total_members = 4 WHERE community_id = 1;
UPDATE community SET total_members = 4 WHERE community_id = 2;
UPDATE community SET total_members = 3 WHERE community_id = 3;
UPDATE community SET total_members = 3 WHERE community_id = 4;
UPDATE community SET total_members = 3 WHERE community_id = 5;

-- 3.4  Categories (global roots, parent_category_id = NULL)
INSERT INTO category (name, icon, community_id, parent_category_id) VALUES
  ('Furniture',    '🛋️', NULL, NULL),   -- 1
  ('Books',        '📚', NULL, NULL),   -- 2
  ('Electronics',  '💻', NULL, NULL),   -- 3
  ('Photography',  '📷', NULL, NULL),   -- 4
  ('Fitness',      '🏋️', NULL, NULL),   -- 5
  ('Clothing',     '👕', NULL, NULL),   -- 6
  ('Services',     '🛠️', NULL, NULL);   -- 7

-- Sub-categories
INSERT INTO category (name, icon, community_id, parent_category_id) VALUES
  ('Sofas',        '🛋️', NULL, 1),   -- 8
  ('Tables/Desks', '🪑', NULL, 1),   -- 9
  ('Textbooks',    '📖', NULL, 2),   -- 10
  ('Novels',       '📕', NULL, 2),   -- 11
  ('Cameras',      '📷', NULL, 4),   -- 12
  ('Lenses',       '🔭', NULL, 4),   -- 13
  ('Laptops',      '💻', NULL, 3),   -- 14
  ('Mobiles',      '📱', NULL, 3);   -- 15

-- 3.5  Tags
INSERT INTO tag (name) VALUES
  ('urgent'),('negotiable'),('new'),('like-new'),
  ('used'),('vintage'),('bundle'),('pickup-only'),
  ('delivery'),('warranty');

-- 3.6  Listings
INSERT INTO listing
  (seller_id,community_id,category_id,title,description,price,price_type,condition,location) VALUES
  (1,1, 8, 'IKEA SÖDERHAMN Sofa',       '3-seat, light grey, 2yr old',         4500.00,'negotiable','like_new','Block 7 Lobby'),
  (1,1, 9, 'Wooden Study Desk',         'Solid wood 120cm with shelf',          1800.00,'fixed',     'good',    'Block 7 Lobby'),
  (2,2,10, 'Data Structures — Cormen',  '4th ed, minor highlights',              350.00,'negotiable','good',    'NIT Campus'),
  (2,2,10, 'OS Concepts — Silberschatz','8th ed, great condition',               280.00,'fixed',     'good',    'NIT Campus'),
  (3,3,12, 'Canon EOS 90D Body',        '~5000 shutter count, with strap',     38000.00,'negotiable','like_new','Mangalore'),
  (3,3, 7, 'Portrait Photography',      '2-hr outdoor session, edited photos',  2500.00,'fixed',     'new',     'Mangalore'),
  (4,4,14, 'ThinkPad X1 Carbon 2022',  '16GB/512GB SSD, excellent',           52000.00,'fixed',     'like_new','Bangalore'),
  (4,4,15, 'OnePlus 10 Pro',           '8/128GB, barely used',                22000.00,'negotiable','like_new','Bangalore'),
  (6,5, 5, 'Adjustable Dumbbells 2×20kg','Bowflex-style, excellent',           8500.00,'fixed',     'like_new','Mysore'),
  (1,2,10, 'DBMS — Navathe 7th Ed',    'Light pencil notes',                    220.00,'negotiable','good',    'NIT Campus'),
  (5,1, 6, 'Handmade Macramé Art',     '60×90cm boho wall hanging',            1200.00,'fixed',     'new',     'Block 7'),
  (8,5, 6, 'Nike Dri-FIT Shorts ×3',  'Pack of 3, worn twice (M)',             650.00,'fixed',     'good',    'Mysore');

-- Update total_listings for communities manually (patch for sample data)
UPDATE community SET total_listings = 4 WHERE community_id = 1;
UPDATE community SET total_listings = 3 WHERE community_id = 2;
UPDATE community SET total_listings = 2 WHERE community_id = 3;
UPDATE community SET total_listings = 2 WHERE community_id = 4;
UPDATE community SET total_listings = 2 WHERE community_id = 5;

-- 3.7  Listing Images
INSERT INTO listing_image (listing_id, image_url, sort_order, is_primary) VALUES
  (1,'https://picsum.photos/seed/sofa/400/300',     0, TRUE),
  (2,'https://picsum.photos/seed/desk/400/300',     0, TRUE),
  (3,'https://picsum.photos/seed/book1/400/300',    0, TRUE),
  (5,'https://picsum.photos/seed/canon/400/300',    0, TRUE),
  (5,'https://picsum.photos/seed/canon2/400/300',   1, FALSE),
  (7,'https://picsum.photos/seed/laptop/400/300',   0, TRUE),
  (9,'https://picsum.photos/seed/dumbbell/400/300', 0, TRUE);

-- 3.8  Listing Tags
INSERT INTO listing_tag (listing_id, tag_id) VALUES
  (1,4),(1,8),   -- sofa: like-new, pickup-only
  (2,5),(2,8),   -- desk: used, pickup-only
  (3,5),(3,2),   -- book: used, negotiable
  (5,4),(5,10),  -- camera: like-new, warranty
  (7,4),(7,10),  -- laptop: like-new, warranty
  (9,4),(9,7);   -- dumbbells: like-new, bundle

-- 3.9  Transactions (completed sales)
INSERT INTO transaction (listing_id,buyer_id,seller_id,amount,status,completed_at) VALUES
  (4, 4, 2, 280.00,   'completed', NOW()),
  (2, 3, 1, 1800.00,  'completed', NOW()),
  (8, 2, 4, 22000.00, 'completed', NOW());

-- Mark those listings as sold
UPDATE listing SET status='sold', sold_at=NOW() WHERE listing_id IN (4,2,8);

-- 3.10  Reviews
INSERT INTO review (transaction_id,reviewer_id,reviewee_id,rating,comment,review_type) VALUES
  (1, 4, 2, 5, 'Book as described. Quick meetup!',        'buyer_to_seller'),
  (1, 2, 4, 4, 'Smooth payment. Good buyer.',             'seller_to_buyer'),
  (2, 3, 1, 5, 'Desk spotless. Very honest seller.',      'buyer_to_seller'),
  (2, 1, 3, 5, 'Great buyer, zero hassle.',               'seller_to_buyer'),
  (3, 2, 4, 4, 'Phone in great shape. Minor delay.',      'buyer_to_seller');

-- avg_rating & total_reviews auto-maintained by trigger.
-- Patch for sample data loaded without triggers:
UPDATE user SET avg_rating=4.50, total_reviews=2 WHERE user_id=1;
UPDATE user SET avg_rating=4.50, total_reviews=2 WHERE user_id=2;
UPDATE user SET avg_rating=5.00, total_reviews=1 WHERE user_id=3;
UPDATE user SET avg_rating=4.50, total_reviews=2 WHERE user_id=4;

-- 3.11  Channels
INSERT INTO channel (community_id, name, channel_type, created_by) VALUES
  (1,'general',         'general',       1),
  (1,'furniture-deals', 'listings',      1),
  (1,'announcements',   'announcements', 1),
  (2,'general',         'general',       2),
  (2,'books',           'listings',      2),
  (2,'tech-stuff',      'listings',      2),
  (3,'general',         'general',       3),
  (3,'gear-listings',   'listings',      3),
  (4,'general',         'general',       4),
  (4,'listings',        'listings',      4);

-- 3.12  Messages
INSERT INTO message (channel_id, sender_id, content) VALUES
  (1, 1, 'Hey everyone! I just posted a sofa listing 🛋️'),
  (1, 2, 'Is it still available?'),
  (1, 1, 'Yes! DM me for details.'),
  (4, 2, 'Anyone have DBMS Navathe 7th edition?'),
  (4, 1, 'Just posted it — check the books channel!'),
  (8, 3, 'New portrait session slots open this weekend!'),
  (8, 4, 'What areas do you cover?');

-- 3.13  Direct Messages
INSERT INTO direct_message (sender_id, receiver_id, content) VALUES
  (2, 1, 'Hi, is the sofa still available?'),
  (1, 2, 'Yes! Come see it tomorrow.'),
  (4, 2, 'Discount on the DBMS book?'),
  (2, 4, 'Best I can do is ₹200.');

-- 3.14  Saved Listings
INSERT INTO saved_listing (user_id, listing_id) VALUES
  (2,1),(3,1),(4,3),(5,7),(1,9),(8,9),(2,7);

-- ================================================================
-- SECTION 4 — STORED PROCEDURES
-- ================================================================

DELIMITER $$

-- --------------------------------------------------------------
-- 4.1  sp_create_listing
-- --------------------------------------------------------------
CREATE PROCEDURE sp_create_listing(
    IN  p_seller_id    INT,
    IN  p_community_id INT,
    IN  p_category_id  INT,
    IN  p_title        VARCHAR(200),
    IN  p_description  TEXT,
    IN  p_price        DECIMAL(10,2),
    IN  p_price_type   VARCHAR(20),
    IN  p_condition    VARCHAR(20),
    IN  p_location     VARCHAR(200),
    OUT p_listing_id   INT,
    OUT p_message      VARCHAR(200)
)
BEGIN
    DECLARE v_is_member    INT DEFAULT 0;
    DECLARE v_is_banned    INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_listing_id = -1;
        SET p_message = 'ERROR: Database error during listing creation.';
    END;

    -- Validate membership
    SELECT COUNT(*), SUM(is_banned)
    INTO   v_is_member, v_is_banned
    FROM   membership
    WHERE  user_id = p_seller_id AND community_id = p_community_id;

    IF v_is_member = 0 THEN
        SET p_listing_id = -1;
        SET p_message = 'ERROR: User is not a member of this community.';
    ELSEIF v_is_banned > 0 THEN
        SET p_listing_id = -1;
        SET p_message = 'ERROR: User is banned from this community.';
    ELSEIF p_price < 0 THEN
        SET p_listing_id = -1;
        SET p_message = 'ERROR: Price cannot be negative.';
    ELSE
        START TRANSACTION;
            INSERT INTO listing
              (seller_id, community_id, category_id, title, description,
               price, price_type, condition, location)
            VALUES
              (p_seller_id, p_community_id, p_category_id, p_title, p_description,
               p_price, p_price_type, p_condition, p_location);

            SET p_listing_id = LAST_INSERT_ID();
            SET p_message    = 'SUCCESS: Listing created.';
        COMMIT;
    END IF;
END$$

-- --------------------------------------------------------------
-- 4.2  sp_join_community
-- --------------------------------------------------------------
CREATE PROCEDURE sp_join_community(
    IN  p_user_id     INT,
    IN  p_invite_code VARCHAR(20),
    OUT p_community_id INT,
    OUT p_message     VARCHAR(200)
)
BEGIN
    DECLARE v_community_id INT   DEFAULT NULL;
    DECLARE v_visibility   VARCHAR(20);
    DECLARE v_already      INT   DEFAULT 0;

    SELECT community_id, visibility
    INTO   v_community_id, v_visibility
    FROM   community
    WHERE  invite_code = p_invite_code
    LIMIT  1;

    IF v_community_id IS NULL THEN
        SET p_community_id = -1;
        SET p_message = 'ERROR: Invalid invite code.';
    ELSE
        SELECT COUNT(*) INTO v_already
        FROM   membership
        WHERE  user_id = p_user_id AND community_id = v_community_id;

        IF v_already > 0 THEN
            SET p_community_id = v_community_id;
            SET p_message = 'INFO: Already a member.';
        ELSE
            START TRANSACTION;
                INSERT INTO membership (user_id, community_id, role)
                VALUES (p_user_id, v_community_id, 'member');
                -- total_members updated by trigger trg_incr_member_count
            COMMIT;
            SET p_community_id = v_community_id;
            SET p_message = 'SUCCESS: Joined community.';
        END IF;
    END IF;
END$$

-- --------------------------------------------------------------
-- 4.3  sp_mark_sold
-- --------------------------------------------------------------
CREATE PROCEDURE sp_mark_sold(
    IN  p_listing_id INT,
    IN  p_buyer_id   INT,
    OUT p_txn_id     INT,
    OUT p_message    VARCHAR(200)
)
BEGIN
    DECLARE v_seller_id INT;
    DECLARE v_price     DECIMAL(10,2);
    DECLARE v_status    VARCHAR(20);

    SELECT seller_id, price, status
    INTO   v_seller_id, v_price, v_status
    FROM   listing
    WHERE  listing_id = p_listing_id;

    IF v_seller_id IS NULL THEN
        SET p_txn_id = -1;
        SET p_message = 'ERROR: Listing not found.';
    ELSEIF v_status NOT IN ('active','reserved') THEN
        SET p_txn_id = -1;
        SET p_message = CONCAT('ERROR: Listing is already ', v_status, '.');
    ELSEIF p_buyer_id = v_seller_id THEN
        SET p_txn_id = -1;
        SET p_message = 'ERROR: Buyer and seller cannot be the same user.';
    ELSE
        START TRANSACTION;
            INSERT INTO transaction
              (listing_id, buyer_id, seller_id, amount, status, completed_at)
            VALUES
              (p_listing_id, p_buyer_id, v_seller_id, v_price, 'completed', NOW());

            SET p_txn_id = LAST_INSERT_ID();

            UPDATE listing
            SET    status = 'sold', sold_at = NOW(), updated_at = NOW()
            WHERE  listing_id = p_listing_id;
            -- total_listings untouched (sold counts as existing listing)

            SET p_message = 'SUCCESS: Item marked as sold.';
        COMMIT;
    END IF;
END$$

-- --------------------------------------------------------------
-- 4.4  sp_add_review
-- --------------------------------------------------------------
CREATE PROCEDURE sp_add_review(
    IN  p_reviewer_id    INT,
    IN  p_transaction_id INT,
    IN  p_rating         TINYINT,
    IN  p_comment        TEXT,
    OUT p_review_id      INT,
    OUT p_message        VARCHAR(200)
)
BEGIN
    DECLARE v_buyer_id  INT;
    DECLARE v_seller_id INT;
    DECLARE v_reviewee  INT;
    DECLARE v_type      VARCHAR(30);
    DECLARE v_already   INT DEFAULT 0;

    IF p_rating NOT BETWEEN 1 AND 5 THEN
        SET p_review_id = -1;
        SET p_message = 'ERROR: Rating must be 1–5.';
    ELSE
        SELECT buyer_id, seller_id
        INTO   v_buyer_id, v_seller_id
        FROM   transaction
        WHERE  transaction_id = p_transaction_id AND status = 'completed';

        IF v_buyer_id IS NULL THEN
            SET p_review_id = -1;
            SET p_message = 'ERROR: Completed transaction not found.';
        ELSEIF p_reviewer_id NOT IN (v_buyer_id, v_seller_id) THEN
            SET p_review_id = -1;
            SET p_message = 'ERROR: Reviewer not party to this transaction.';
        ELSE
            IF p_reviewer_id = v_buyer_id THEN
                SET v_reviewee = v_seller_id;
                SET v_type     = 'buyer_to_seller';
            ELSE
                SET v_reviewee = v_buyer_id;
                SET v_type     = 'seller_to_buyer';
            END IF;

            SELECT COUNT(*) INTO v_already
            FROM   review
            WHERE  transaction_id = p_transaction_id
              AND  reviewer_id    = p_reviewer_id;

            IF v_already > 0 THEN
                SET p_review_id = -1;
                SET p_message = 'ERROR: Already reviewed this transaction.';
            ELSE
                INSERT INTO review
                  (transaction_id, reviewer_id, reviewee_id, rating, comment, review_type)
                VALUES
                  (p_transaction_id, p_reviewer_id, v_reviewee, p_rating, p_comment, v_type);

                SET p_review_id = LAST_INSERT_ID();
                SET p_message   = 'SUCCESS: Review added.';
                -- avg_rating updated by trigger trg_update_seller_rating
            END IF;
        END IF;
    END IF;
END$$

-- --------------------------------------------------------------
-- 4.5  sp_search_listings  (filterable)
-- --------------------------------------------------------------
CREATE PROCEDURE sp_search_listings(
    IN p_community_id INT,
    IN p_category_id  INT,
    IN p_keyword      VARCHAR(200),
    IN p_min_price    DECIMAL(10,2),
    IN p_max_price    DECIMAL(10,2),
    IN p_condition    VARCHAR(20),
    IN p_price_type   VARCHAR(20)
)
BEGIN
    SELECT
        l.listing_id,
        l.title,
        l.price,
        l.price_type,
        l.condition,
            l.`condition`,
        l.status,
        l.location,
        l.view_count,
        l.created_at,
        u.username        AS seller,
        u.avg_rating      AS seller_rating,
        cat.name          AS category,
        com.name          AS community,
        img.image_url     AS primary_image
    FROM listing l
    JOIN user        u   ON l.seller_id    = u.user_id
    JOIN community   com ON l.community_id = com.community_id
    LEFT JOIN category    cat ON l.category_id  = cat.category_id
    LEFT JOIN listing_image img
           ON l.listing_id = img.listing_id AND img.is_primary = TRUE
    WHERE l.status = 'active'
      AND (p_community_id IS NULL OR l.community_id = p_community_id)
      AND (p_category_id  IS NULL OR l.category_id  = p_category_id)
      AND (p_keyword IS NULL
           OR l.title       LIKE CONCAT('%', p_keyword, '%')
           OR l.description LIKE CONCAT('%', p_keyword, '%'))
      AND (p_min_price IS NULL OR l.price >= p_min_price)
      AND (p_max_price IS NULL OR l.price <= p_max_price)
      AND (p_condition IS NULL OR l.condition = p_condition)
        AND (p_condition IS NULL OR l.`condition` = p_condition)
      AND (p_price_type IS NULL OR l.price_type = p_price_type)
    ORDER BY l.created_at DESC;
END$$

DELIMITER ;

-- ================================================================
-- SECTION 5 — TRIGGERS
-- ================================================================

DELIMITER $$

-- --------------------------------------------------------------
-- 5.1  Auto-update seller avg_rating after INSERT on review
-- --------------------------------------------------------------
CREATE TRIGGER trg_update_rating_insert
AFTER INSERT ON review
FOR EACH ROW
BEGIN
    UPDATE user
    SET avg_rating    = (SELECT ROUND(AVG(rating),2) FROM review WHERE reviewee_id = NEW.reviewee_id),
        total_reviews = (SELECT COUNT(*)              FROM review WHERE reviewee_id = NEW.reviewee_id)
    WHERE user_id = NEW.reviewee_id;
END$$

-- --------------------------------------------------------------
-- 5.2  Re-compute rating after DELETE on review
-- --------------------------------------------------------------
CREATE TRIGGER trg_update_rating_delete
AFTER DELETE ON review
FOR EACH ROW
BEGIN
    UPDATE user
    SET avg_rating    = COALESCE((SELECT ROUND(AVG(rating),2) FROM review WHERE reviewee_id = OLD.reviewee_id), 0.00),
        total_reviews = (SELECT COUNT(*) FROM review WHERE reviewee_id = OLD.reviewee_id)
    WHERE user_id = OLD.reviewee_id;
END$$

-- --------------------------------------------------------------
-- 5.3  Prevent duplicate membership (belt-and-suspenders)
--      UNIQUE constraint handles it at DB level; trigger gives a
--      cleaner error message for application layer.
-- --------------------------------------------------------------
CREATE TRIGGER trg_prevent_dup_membership
BEFORE INSERT ON membership
FOR EACH ROW
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
    FROM   membership
    WHERE  user_id = NEW.user_id AND community_id = NEW.community_id;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User is already a member of this community.';
    END IF;
END$$

-- --------------------------------------------------------------
-- 5.4  Increment community.total_members on membership INSERT
-- --------------------------------------------------------------
CREATE TRIGGER trg_incr_member_count
AFTER INSERT ON membership
FOR EACH ROW
BEGIN
    UPDATE community
    SET total_members = total_members + 1
    WHERE community_id = NEW.community_id;
END$$

-- --------------------------------------------------------------
-- 5.5  Decrement community.total_members on membership DELETE
-- --------------------------------------------------------------
CREATE TRIGGER trg_decr_member_count
AFTER DELETE ON membership
FOR EACH ROW
BEGIN
    UPDATE community
    SET total_members = GREATEST(0, total_members - 1)
    WHERE community_id = OLD.community_id;
END$$

-- --------------------------------------------------------------
-- 5.6  Increment community.total_listings on listing INSERT
-- --------------------------------------------------------------
CREATE TRIGGER trg_incr_listing_count
AFTER INSERT ON listing
FOR EACH ROW
BEGIN
    UPDATE community
    SET total_listings = total_listings + 1
    WHERE community_id = NEW.community_id;
END$$

-- --------------------------------------------------------------
-- 5.7  Decrement community.total_listings on listing DELETE
-- --------------------------------------------------------------
CREATE TRIGGER trg_decr_listing_count
AFTER DELETE ON listing
FOR EACH ROW
BEGIN
    UPDATE community
    SET total_listings = GREATEST(0, total_listings - 1)
    WHERE community_id = OLD.community_id;
END$$

-- --------------------------------------------------------------
-- 5.8  Auto-set listing.updated_at on status change
-- --------------------------------------------------------------
CREATE TRIGGER trg_listing_status_ts
BEFORE UPDATE ON listing
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status THEN
        SET NEW.updated_at = NOW();
        IF NEW.status = 'sold' AND NEW.sold_at IS NULL THEN
            SET NEW.sold_at = NOW();
        END IF;
    END IF;
END$$

-- --------------------------------------------------------------
-- 5.9  Prevent self-report
-- --------------------------------------------------------------
CREATE TRIGGER trg_no_self_report
BEFORE INSERT ON report
FOR EACH ROW
BEGIN
    DECLARE v_seller INT;
    SELECT seller_id INTO v_seller FROM listing WHERE listing_id = NEW.listing_id;
    IF v_seller = NEW.reporter_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot report your own listing.';
    END IF;
END$$

DELIMITER ;

-- ================================================================
-- SECTION 6 — QUERIES
-- ================================================================

-- ---- BASIC -------------------------------------------------------

-- B1: Insert a new user
INSERT INTO user (username, email, password_hash, full_name)
VALUES ('new_user', 'new@mail.com', SHA2('password', 256), 'New User');

-- B2: Insert a new listing (use sp_create_listing in production)
INSERT INTO listing (seller_id, community_id, category_id, title, price, price_type, condition)
INSERT INTO listing (seller_id, community_id, category_id, title, price, price_type, `condition`)
    l.`condition`,
VALUES (1, 1, 8, 'Test Listing', 999.00, 'fixed', 'good');

-- B3: Update listing status to sold
UPDATE listing
SET status = 'sold', sold_at = NOW()
WHERE listing_id = 1 AND seller_id = 1;

-- B4: Soft-delete a listing
UPDATE listing
SET status = 'deleted'
WHERE listing_id = 12 AND seller_id = 8;

-- B5: Increment view count
UPDATE listing SET view_count = view_count + 1 WHERE listing_id = 5;

-- ---- COMPLEX ------------------------------------------------------

-- C1: Top sellers per community (by completed sales count)
SELECT
    com.name                              AS community,
    u.user_id,
    u.username,
    u.avg_rating,
    COUNT(t.transaction_id)               AS sales_count,
    SUM(t.amount)                         AS total_revenue,
    RANK() OVER (
        PARTITION BY com.community_id
        ORDER BY COUNT(t.transaction_id) DESC
    )                                     AS rank_in_community
FROM transaction t
JOIN user      u   ON t.seller_id     = u.user_id
JOIN listing   l   ON t.listing_id    = l.listing_id
JOIN community com ON l.community_id  = com.community_id
WHERE t.status = 'completed'
GROUP BY com.community_id, com.name, u.user_id, u.username, u.avg_rating
ORDER BY com.name, rank_in_community;

-- C2: Most active communities (listings + members + sold rate)
SELECT
    c.community_id,
    c.name,
    c.total_members,
    c.total_listings,
    COUNT(l.listing_id)                                        AS active_listings,
    COUNT(CASE WHEN l.status = 'sold' THEN 1 END)             AS sold_count,
    ROUND(
        COUNT(CASE WHEN l.status='sold' THEN 1 END) * 100.0
        / NULLIF(COUNT(l.listing_id), 0), 1
    )                                                          AS sell_through_pct,
    COUNT(DISTINCT m.user_id)                                  AS active_members
FROM community c
LEFT JOIN listing    l ON c.community_id = l.community_id
LEFT JOIN membership m ON c.community_id = m.community_id AND m.is_banned = FALSE
GROUP BY c.community_id, c.name, c.total_members, c.total_listings
ORDER BY active_listings DESC, c.total_members DESC;

-- C3: Listings by category with price + condition filter
SELECT
    cat.name           AS category,
    l.listing_id,
    l.title,
    l.price,
    l.price_type,
    l.condition,
    l.status,
    l.location,
    u.username         AS seller,
    u.avg_rating       AS seller_rating,
    com.name           AS community,
    img.image_url      AS primary_image
FROM listing l
JOIN user          u   ON l.seller_id    = u.user_id
JOIN community     com ON l.community_id = com.community_id
LEFT JOIN category cat ON l.category_id  = cat.category_id
LEFT JOIN listing_image img
       ON l.listing_id = img.listing_id AND img.is_primary = TRUE
WHERE l.status      = 'active'
  AND cat.name      = 'Books'           -- change as needed
  AND l.price       BETWEEN 100 AND 500 -- price range filter
  AND l.condition   IN ('good','like_new')
    AND l.`condition`   IN ('good','like_new')
    l.`condition`,
ORDER BY l.price ASC;

-- C4: Highest-rated users (min 2 reviews)
SELECT
    u.user_id,
    u.username,
    u.full_name,
    u.avg_rating,
    u.total_reviews,
    COUNT(DISTINCT m.community_id)                AS communities_in,
    COUNT(DISTINCT l.listing_id)                  AS listings_posted,
    COUNT(DISTINCT CASE WHEN l.status='sold'
                        THEN l.listing_id END)    AS items_sold
FROM user u
JOIN review      r ON u.user_id = r.reviewee_id
LEFT JOIN membership m ON u.user_id = m.user_id
LEFT JOIN listing    l ON u.user_id = l.seller_id
WHERE u.total_reviews >= 2
GROUP BY u.user_id, u.username, u.full_name, u.avg_rating, u.total_reviews
ORDER BY u.avg_rating DESC, u.total_reviews DESC
LIMIT 10;

-- C5: Full listing detail with tags (multi-table join)
SELECT
    l.listing_id,
    l.title,
    l.price,
    l.price_type,
    l.condition,
    l.status,
    l.view_count,
    l.created_at,
    u.username                                          AS seller,
    u.avg_rating                                        AS seller_rating,
    cat.name                                            AS category,
    com.name                                            AS community,
    GROUP_CONCAT(DISTINCT t.name ORDER BY t.name)       AS tags,
    GROUP_CONCAT(DISTINCT img.image_url ORDER BY img.sort_order) AS images
FROM listing l
JOIN user       u   ON l.seller_id    = u.user_id
JOIN community  com ON l.community_id = com.community_id
LEFT JOIN category      cat ON l.category_id  = cat.category_id
LEFT JOIN listing_tag   lt  ON l.listing_id   = lt.listing_id
LEFT JOIN tag           t   ON lt.tag_id      = t.tag_id
LEFT JOIN listing_image img ON l.listing_id   = img.listing_id
WHERE l.listing_id = 5  -- parameterise per listing
GROUP BY l.listing_id, l.title, l.price, l.price_type,
         l.condition, l.status, l.view_count, l.created_at,
                 l.`condition`, l.status, l.view_count, l.created_at,
         u.username, u.avg_rating, cat.name, com.name;

-- C6: Community revenue summary
SELECT
    com.name                         AS community,
    COUNT(t.transaction_id)          AS total_transactions,
    SUM(t.amount)                    AS gross_revenue,
    AVG(t.amount)                    AS avg_deal_size,
    MAX(t.amount)                    AS largest_deal,
    MIN(t.amount)                    AS smallest_deal
FROM transaction t
JOIN listing    l   ON t.listing_id   = l.listing_id
JOIN community  com ON l.community_id = com.community_id
WHERE t.status = 'completed'
GROUP BY com.community_id, com.name
ORDER BY gross_revenue DESC;

-- C7: User activity dashboard (seller + buyer + community view)
SELECT
    u.user_id,
    u.username,
    u.avg_rating,
    u.total_reviews,
    COUNT(DISTINCT m.community_id)                          AS communities_joined,
    COUNT(DISTINCT l.listing_id)                            AS listings_created,
    COUNT(DISTINCT CASE WHEN l.status='sold'
                   THEN l.listing_id END)                   AS items_sold,
    COUNT(DISTINCT ts.transaction_id)                       AS purchases_made,
    COALESCE(SUM(ts_sell.amount), 0)                        AS total_earned,
    COALESCE(SUM(ts.amount), 0)                             AS total_spent
FROM user u
LEFT JOIN membership  m      ON u.user_id = m.user_id
LEFT JOIN listing     l      ON u.user_id = l.seller_id
LEFT JOIN transaction ts     ON u.user_id = ts.buyer_id  AND ts.status='completed'
LEFT JOIN transaction ts_sell ON u.user_id = ts_sell.seller_id AND ts_sell.status='completed'
GROUP BY u.user_id, u.username, u.avg_rating, u.total_reviews
ORDER BY items_sold DESC;

-- C8: Watchlisted listings with demand signal
SELECT
    l.listing_id,
    l.title,
    l.price,
    u.username             AS seller,
    com.name               AS community,
    COUNT(sl.user_id)      AS watchlist_count,
    l.view_count
FROM listing       l
JOIN saved_listing sl  ON l.listing_id   = sl.listing_id
JOIN user          u   ON l.seller_id    = u.user_id
JOIN community     com ON l.community_id = com.community_id
WHERE l.status = 'active'
GROUP BY l.listing_id, l.title, l.price, u.username, com.name, l.view_count
ORDER BY watchlist_count DESC, l.view_count DESC;

-- C9: Category hierarchy with listing counts
SELECT
    COALESCE(p.name, '—')  AS parent_category,
    c.name                 AS category,
    COUNT(l.listing_id)    AS total_listings,
    COUNT(CASE WHEN l.status='active' THEN 1 END) AS active_listings,
    ROUND(AVG(l.price), 2) AS avg_price
FROM category c
LEFT JOIN category c AS p   ON c.parent_category_id = p.category_id
LEFT JOIN listing  l         ON c.category_id        = l.category_id
GROUP BY c.category_id, parent_category, c.name
ORDER BY parent_category, c.name;

-- C10: Unread DMs per user (inbox summary)
SELECT
    u.username                         AS recipient,
    COUNT(dm.dm_id)                    AS unread_count,
    COUNT(DISTINCT dm.sender_id)       AS unique_senders
FROM direct_message dm
JOIN user u ON dm.receiver_id = u.user_id
WHERE dm.is_read = FALSE
GROUP BY u.user_id, u.username
ORDER BY unread_count DESC;

-- ================================================================
-- SECTION 7 — VIEWS (convenience for frontend queries)
-- ================================================================

CREATE OR REPLACE VIEW vw_active_listings AS
SELECT
    l.listing_id, l.title, l.price, l.price_type, l.condition,
        l.listing_id, l.title, l.price, l.price_type, l.`condition`,
    FROM `transaction` t
    FROM `transaction` t
    LEFT JOIN `transaction` ts_sell ON u.user_id = ts_sell.seller_id AND ts_sell.status='completed'
    l.status, l.location, l.view_count, l.created_at,
    u.username     AS seller,
    u.avg_rating   AS seller_rating,
    cat.name       AS category,
    com.name       AS community,
    com.community_id,
    img.image_url  AS primary_image
FROM listing l
JOIN user        u   ON l.seller_id    = u.user_id
JOIN community   com ON l.community_id = com.community_id
LEFT JOIN category       cat ON l.category_id  = cat.category_id
LEFT JOIN listing_image  img ON l.listing_id   = img.listing_id AND img.is_primary = TRUE
WHERE l.status = 'active';

CREATE OR REPLACE VIEW vw_community_stats AS
SELECT
    c.community_id,
    c.name,
    c.total_members,
    c.total_listings,
    c.visibility,
    c.created_at,
    u.username      AS owner,
    COUNT(DISTINCT l.listing_id)                     AS active_listings,
    COALESCE(SUM(t.amount), 0)                       AS total_gmv
FROM community c
JOIN user          u ON c.created_by   = u.user_id
LEFT JOIN membership  m ON c.community_id = m.community_id  AND m.is_banned = FALSE
LEFT JOIN listing     l ON c.community_id = l.community_id  AND l.status    = 'active'
LEFT JOIN transaction t ON l.listing_id   = t.listing_id    AND t.status    = 'completed'
LEFT JOIN `transaction` t ON l.listing_id   = t.listing_id    AND t.status    = 'completed'
GROUP BY c.community_id, c.name, c.total_members, c.total_listings,
         c.visibility, c.created_at, u.username;

-- ================================================================
-- END OF SCRIPT
-- ================================================================

-- ================================================================
-- ADDENDUM: USER SESSION TABLE (login support)
-- ================================================================

-- ----------------------------------------------------------------
-- LOGIN TABLE: user_session
-- Stores active sessions created on login.
-- Mirrors what the login screen does:
--   INSERT INTO user_session on login success
--   DELETE FROM user_session on logout
--   SELECT to validate token on each request
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_session (
    session_id  INT           NOT NULL AUTO_INCREMENT,
    user_id     INT           NOT NULL,
    token       VARCHAR(36)   NOT NULL,          -- UUID() from MySQL
    ip_address  VARCHAR(45),
    user_agent  VARCHAR(255),
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP     NOT NULL DEFAULT (DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 7 DAY)),
    is_revoked  BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_session       PRIMARY KEY (session_id),
    CONSTRAINT uq_token         UNIQUE (token),
    CONSTRAINT fk_sess_user     FOREIGN KEY (user_id)
        REFERENCES user(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_expiry       CHECK (expires_at > created_at)
) ENGINE=InnoDB;

CREATE INDEX idx_session_token   ON user_session(token);
CREATE INDEX idx_session_user    ON user_session(user_id);
CREATE INDEX idx_session_expiry  ON user_session(expires_at);

-- ----------------------------------------------------------------
-- PROCEDURES for session management
-- ----------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE sp_login(
    IN  p_username     VARCHAR(100),   -- username OR email
    IN  p_password_raw VARCHAR(100),   -- plaintext from client
    IN  p_ip           VARCHAR(45),
    IN  p_user_agent   VARCHAR(255),
    OUT p_token        VARCHAR(36),
    OUT p_message      VARCHAR(200)
)
BEGIN
    DECLARE v_user_id   INT;
    DECLARE v_status    VARCHAR(20);
    DECLARE v_token     VARCHAR(36);

    SELECT user_id, status
    INTO   v_user_id, v_status
    FROM   user
    WHERE  (username = p_username OR email = p_username)
      AND  password_hash = SHA2(p_password_raw, 256)
    LIMIT 1;

    IF v_user_id IS NULL THEN
        SET p_token   = NULL;
        SET p_message = 'ERROR: Invalid credentials.';
    ELSEIF v_status != 'active' THEN
        SET p_token   = NULL;
        SET p_message = 'ERROR: Account is suspended or deleted.';
    ELSE
        SET v_token = UUID();
        INSERT INTO user_session(user_id, token, ip_address, user_agent, expires_at)
        VALUES (v_user_id, v_token, p_ip, p_user_agent,
                DATE_ADD(NOW(), INTERVAL 7 DAY));

        UPDATE user SET last_active = NOW() WHERE user_id = v_user_id;

        SET p_token   = v_token;
        SET p_message = CONCAT('SUCCESS: user_id=', v_user_id);
    END IF;
END$$

CREATE PROCEDURE sp_logout(
    IN  p_token   VARCHAR(36),
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_rows INT DEFAULT 0;
    UPDATE user_session SET is_revoked = TRUE WHERE token = p_token;
    SET v_rows = ROW_COUNT();
    SET p_message = IF(v_rows > 0, 'SUCCESS: Session revoked.', 'ERROR: Token not found.');
END$$

CREATE PROCEDURE sp_validate_session(
    IN  p_token   VARCHAR(36),
    OUT p_user_id INT,
    OUT p_message VARCHAR(200)
)
BEGIN
    SELECT user_id INTO p_user_id
    FROM   user_session
    WHERE  token      = p_token
      AND  is_revoked = FALSE
      AND  expires_at > NOW()
    LIMIT 1;

    IF p_user_id IS NULL THEN
        SET p_message = 'ERROR: Invalid or expired session.';
    ELSE
        UPDATE user SET last_active = NOW() WHERE user_id = p_user_id;
        SET p_message = CONCAT('SUCCESS: user_id=', p_user_id);
    END IF;
END$$

DELIMITER ;

-- ----------------------------------------------------------------
-- TRIGGER: auto-expire old sessions (clean up on new login)
-- ----------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_cleanup_expired_sessions
AFTER INSERT ON user_session
FOR EACH ROW
BEGIN
    DELETE FROM user_session
    WHERE user_id    = NEW.user_id
      AND is_revoked = FALSE
      AND expires_at < NOW()
      AND session_id != NEW.session_id;
END$$
DELIMITER ;

-- ----------------------------------------------------------------
-- SAMPLE QUERIES for login system
-- ----------------------------------------------------------------

-- Validate a session token (called on every protected page load)
-- CALL sp_validate_session('token-uuid-here', @uid, @msg);

-- See all active sessions for a user
SELECT session_id, token, ip_address, created_at, expires_at
FROM user_session
WHERE user_id = 1 AND is_revoked = FALSE AND expires_at > NOW();

-- Revoke all sessions for a user (force logout everywhere)
UPDATE user_session SET is_revoked = TRUE WHERE user_id = 1;
