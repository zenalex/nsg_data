0.3.0-beta.1
Major improvements and bug fixes (Beta release)
18.07.2025

**New Features:**
- Added password validation and strength checking
- Added new table logic for improved data handling
- Added NsgDataItem.select functionality
- Added autoSelectServer feature
- Added NsgPeriod.BeginOfDay utility
- Added referenceItemPage functionality
- Added provider.setLocale support
- Added NsgBaseController.listPageOpen method
- Added NsgBarcodeListener for barcode scanning
- Added filterItems to controller
- Added firebaseToken support
- Added type filter functionality
- Added NsgDataItem.isEqual method
- Added context to functions for better error handling
- Added defaultControllerMode
- Added controller.deleteItems and controller.postItems methods
- Added local database support with Hive
- Added NsgDataRequest.addAllReferences
- Added defaultProgressIndicator
- Added double.nsgRoundToDouble extension
- Added removeRow functionality
- Added NsgDataField.compareTo method
- Added newRecordFill functionality
- Added referenceField formattedValue
- Added NsgDataItem.defaultController
- Added NsgDataField.formattedValue and presentation
- Added controller.itemNewPageOpen
- Added NsgDataTableController
- Added imageController support

**Bug Fixes:**
- Fixed NsgDataTable allRows clone issues
- Fixed table rows not containing deleted rows
- Fixed password validation
- Fixed deletion of rows from table parts with new logic
- Fixed shared_preference security issues
- Fixed localDb for Web platform
- Fixed auto-reading of untyped references through dot notation
- Fixed NsgBaseController null state issues
- Fixed save to local database
- Fixed date localization and removed warnings
- Fixed local db comparison issues
- Fixed readNestedField functionality
- Fixed error serialization when comparing enum to list
- Fixed localDb creation on iOS
- Fixed copyFieldsValues
- Fixed Enum handling
- Fixed extension data type in web
- Fixed setAndRefreshSelectedItem and reading references for untyped objects
- Fixed default controller search functionality
- Fixed login issues
- Fixed refreshItem when Id is empty
- Fixed enum error handling
- Fixed future progress in NsgBaseController empty refreshItem
- Fixed inheritance issues
- Fixed NsgBarcodeListener subscription
- Fixed login form field colors
- Fixed exception handling in NsgBaseController
- Fixed DateTime fields timezone handling
- Fixed showExceptionDialog
- Fixed DateTime handling
- Fixed warnings
- Fixed login/verification text
- Fixed local post functionality
- Fixed NsgFutureProgress exception handling
- Fixed delay in data provider
- Fixed NsgTable functionality
- Fixed phone number validation
- Fixed reading references > 2 levels deep
- Fixed item deletion
- Fixed deleteItems functionality
- Fixed dataTable post
- Fixed NsgReferenceListField
- Fixed login without password
- Fixed table part position after post
- Fixed web login
- Fixed NsgTable.DataPagePost
- Fixed sendNotify
- Fixed delete table row
- Fixed postItemQueue
- Fixed favorites reading in controller
- Fixed dataTable.removeRow
- Fixed comparison for localdb (NsgDataItem to id)
- Fixed post items
- Fixed price string handling
- Fixed localDb cache
- Fixed bool.compareTo
- Fixed NsgReferenceListField.compareTo
- Fixed web compatibility
- Fixed localDb on iOS
- Fixed Builder functionality
- Fixed post functionality
- Fixed table updates
- Fixed string filter
- Fixed adding rows to table
- Fixed reading existing rows in table parts
- Fixed NsgPeriod.toString
- Fixed form element return without current row
- Fixed NsgDataItem.clone
- Fixed adding rows to table
- Fixed string to double assignment
- Fixed untyped reference for web
- Fixed field reading
- Fixed NsgInput
- Fixed double field
- Fixed table part updates in new element
- Fixed post-reading of UntypedReference
- Fixed client-side sorting
- Fixed itemPagePost
- Fixed refreshItem
- Fixed filter for text fields and references only
- Fixed field reading
- Fixed table loading in subordinate controller
- Fixed NsgFilter
- Fixed caching
- Fixed element updates

**Dependencies:**
- Updated intl to ^0.20.2
- Added package_info_plus: ^8.0.2
- Added device_info_plus: ^11.0.0
- Updated Flutter SDK requirements

0.2.0
Many improvements based on user and developer experience 
02.06.2022

0.1.0
Big update. You can use package in production
02.06.2022

0.0.3
NsgPhoneLoginPage improvements.
06.10.2020

0.0.1
Initial commit
20.08.2020

Author: Aleksei Zenkov (zenkov25@gmail.com)