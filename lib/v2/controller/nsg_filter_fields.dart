import 'package:nsg_data/controllers/nsg_controller_filter.dart';
import 'package:nsg_data/helpers/nsg_period_new.dart';

class NsgSearchStringFilterField extends FilterField<String> {
  NsgSearchStringFilterField() : super('searchString');
}

class NsgPeriodFilterField extends FilterField<NsgTypedPeriod> {
  NsgPeriodFilterField() : super('nsgPeriod');
}
