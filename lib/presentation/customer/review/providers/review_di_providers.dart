import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/review_remote_data_source.dart';
import 'package:qradar/data/repositories/review_repository_impl.dart';
import 'package:qradar/domain/repositories/review_repository.dart';
import 'package:qradar/domain/usecases/get_my_store_review_use_case.dart';
import 'package:qradar/domain/usecases/get_store_reviews_use_case.dart';
import 'package:qradar/domain/usecases/submit_store_review_use_case.dart';

final reviewRemoteDataSourceProvider = Provider<ReviewRemoteDataSource>((ref) {
  return ReviewRemoteDataSource();
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepositoryImpl(ref.watch(reviewRemoteDataSourceProvider));
});

final submitStoreReviewUseCaseProvider = Provider<SubmitStoreReviewUseCase>((
  ref,
) {
  return SubmitStoreReviewUseCase(ref.watch(reviewRepositoryProvider));
});

final getStoreReviewsUseCaseProvider = Provider<GetStoreReviewsUseCase>((ref) {
  return GetStoreReviewsUseCase(ref.watch(reviewRepositoryProvider));
});

final getMyStoreReviewUseCaseProvider = Provider<GetMyStoreReviewUseCase>((
  ref,
) {
  return GetMyStoreReviewUseCase(ref.watch(reviewRepositoryProvider));
});
