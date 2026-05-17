import { MapPin, Star, ChevronRight } from "lucide-react";
import { QLogo } from "../QradarLogo";
import { ImageWithFallback } from "../figma/ImageWithFallback";
import { useState } from "react";

export function HomePage() {
  const [selectedFilters, setSelectedFilters] = useState<string[]>(["추천메뉴"]);

  const filterCategories = [
    "추천메뉴", "커피", "우리의 디카페인",
    "논커피/파일라떼", "티", "스무디/프라페",
    "에이드/쥬스", "밀크쉐이크", "아이스크림",
    "푸드/디저트", "MD상품", "콜라보 메뉴"
  ];

  const toggleFilter = (filter: string) => {
    setSelectedFilters(prev =>
      prev.includes(filter)
        ? prev.filter(f => f !== filter)
        : [...prev, filter]
    );
  };

  const nearbyCafes = [
    {
      id: 1,
      name: "스타벅스 강남점",
      distance: "1.2km",
      rating: 4.8,
      image: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjb2ZmZWUlMjBzaG9wJTIwaW50ZXJpb3J8ZW58MXx8fHwxNzc1NjI2NjYyfDA&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "S"
    },
    {
      id: 2,
      name: "블루보틀 서울점",
      distance: "0.8km",
      rating: 4.9,
      image: "https://images.unsplash.com/photo-1684439670717-b1147a7e7534?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxpY2VkJTIwY29mZmVlJTIwZHJpbmt8ZW58MXx8fHwxNzc1NjU0ODA1fDA&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "S"
    },
    {
      id: 3,
      name: "카페 온리",
      distance: "1.5km",
      rating: 4.7,
      image: "https://images.unsplash.com/photo-1672570050756-4f1953bde478?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjb2ZmZWUlMjBiZWFucyUyMHJvYXN0aW5nfGVufDF8fHx8MTc3NTU1MjYzM3ww&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "A"
    },
  ];

  const allStores = [
    {
      id: 1,
      name: "스타벅스 강남점",
      distance: "1.2km",
      rating: 4.8,
      image: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjb2ZmZWUlMjBzaG9wJTIwaW50ZXJpb3J8ZW58MXx8fHwxNzc1NjI2NjYyfDA&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "S",
      categories: ["추천메뉴", "커피", "푸드/디저트"]
    },
    {
      id: 2,
      name: "블루보틀 서울점",
      distance: "0.8km",
      rating: 4.9,
      image: "https://images.unsplash.com/photo-1684439670717-b1147a7e7534?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxpY2VkJTIwY29mZmVlJTIwZHJpbmt8ZW58MXx8fHwxNzc1NjU0ODA1fDA&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "S",
      categories: ["추천메뉴", "우리의 디카페인", "티"]
    },
    {
      id: 3,
      name: "카페 온리",
      distance: "1.5km",
      rating: 4.7,
      image: "https://images.unsplash.com/photo-1672570050756-4f1953bde478?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjb2ZmZWUlMjBiZWFucyUyMHJvYXN0aW5nfGVufDF8fHx8MTc3NTU1MjYzM3ww&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "A",
      categories: ["커피", "스무디/프라페", "에이드/쥬스"]
    },
    {
      id: 4,
      name: "커피 스미스",
      distance: "2.1km",
      rating: 4.6,
      image: "https://images.unsplash.com/photo-1669162364316-a74b2d661d1e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxsYXR0ZSUyMGFydCUyMGNvZmZlZXxlbnwxfHx8fDE3NzU2MTA4MDJ8MA&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "S",
      categories: ["추천메뉴", "밀크쉐이크", "아이스크림"]
    },
    {
      id: 5,
      name: "화이트 커피",
      distance: "1.8km",
      rating: 4.5,
      image: "https://images.unsplash.com/photo-1521017432531-fbd92d768814?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjb2ZmZWUlMjBzaG9wJTIwaW50ZXJpb3J8ZW58MXx8fHwxNzc1NjI2NjYyfDA&ixlib=rb-4.1.0&q=80&w=1080",
      grade: "A",
      categories: ["논커피/파일라떼", "MD상품", "콜라보 메뉴"]
    },
  ];

  const filteredStores = allStores.filter(store =>
    selectedFilters.some(filter => store.categories.includes(filter))
  );

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white pb-28">
      {/* 헤더 - 미드나잇 배경 */}
      <div className="bg-gradient-to-br from-slate-900 to-slate-800 px-6 pt-8 pb-6 rounded-bl-3xl">
        {/* 브랜드 로고 */}
        <div className="flex items-center mb-2">
          <QLogo size={48} color="#ffffff" />
          <h1 className="text-2xl font-bold text-white ml-0.2 mt-3">
            uality Grader Radar
          </h1>
        </div>

        {/* 환영 메시지 */}
        <p className="text-xl text-white">
          <span className="font-bold ml-2">홍길동</span>님 어서오세요.
        </p>
      </div>

      {/* 주변 매장 */}
      <div className="mb-8 mt-6">
        <div className="px-6 mb-4">
          <h2 className="text-lg font-bold text-gray-900">주변매장</h2>
        </div>

        <div className="overflow-x-auto scrollbar-hide">
          <div className="flex gap-3 px-6">
            {nearbyCafes.map((cafe) => (
              <div
                key={cafe.id}
                className="bg-white rounded-2xl overflow-hidden shadow-sm hover:shadow-lg transition-all border border-gray-100 flex-shrink-0"
                style={{ width: 'calc(40% - 6px)' }}
              >
                <div className="relative h-32">
                  <ImageWithFallback
                    src={cafe.image}
                    alt={cafe.name}
                    className="w-full h-full object-cover"
                  />
                  <div className="absolute top-2 right-2 bg-slate-900 text-white text-xs font-bold px-2 py-1 rounded-full">
                    {cafe.grade}급
                  </div>
                </div>
                <div className="p-3">
                  <h3 className="font-bold text-gray-900 text-sm mb-2">{cafe.name}</h3>
                  <div className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-1 text-amber-500">
                      <Star className="w-3 h-3 fill-amber-500" />
                      <span className="font-medium">{cafe.rating}</span>
                    </div>
                    <div className="flex items-center gap-1 text-gray-500">
                      <MapPin className="w-3 h-3" />
                      <span>{cafe.distance}</span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* 필터 카테고리 */}
      <div className="px-6 pb-6">
        <h2 className="text-lg font-bold text-gray-900 mb-4">카테고리</h2>
        <div className="flex flex-wrap gap-2">
          {filterCategories.map((category) => (
            <button
              key={category}
              onClick={() => toggleFilter(category)}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
                selectedFilters.includes(category)
                  ? "bg-slate-900 text-white"
                  : "bg-white text-gray-700 border border-gray-200 hover:border-slate-300"
              }`}
            >
              {category}
            </button>
          ))}
        </div>
      </div>

      {/* 맞춤 추천 - 필터링됨 */}
      <div className="px-6 pb-8">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-bold text-gray-900">맞춤 추천 ({filteredStores.length})</h2>
          <button className="text-sm text-sky-500 hover:text-sky-600 transition-colors">
            전체보기
          </button>
        </div>

        <div className="space-y-3">
          {filteredStores.map((store) => (
            <div
              key={store.id}
              className="bg-white rounded-2xl overflow-hidden shadow-sm hover:shadow-lg transition-all border border-gray-100 flex"
            >
              <div className="relative w-24 h-24 flex-shrink-0">
                <ImageWithFallback
                  src={store.image}
                  alt={store.name}
                  className="w-full h-full object-cover"
                />
                <div className="absolute top-2 left-2 bg-slate-900 text-white text-xs font-bold px-2 py-1 rounded-full">
                  {store.grade}급
                </div>
              </div>
              <div className="flex-1 p-3 flex flex-col justify-between">
                <h3 className="font-bold text-gray-900 text-sm">{store.name}</h3>
                <div className="flex items-center justify-between text-xs">
                  <div className="flex items-center gap-1 text-amber-500">
                    <Star className="w-3 h-3 fill-amber-500" />
                    <span className="font-medium">{store.rating}</span>
                  </div>
                  <div className="flex items-center gap-1 text-gray-500">
                    <MapPin className="w-3 h-3" />
                    <span>{store.distance}</span>
                  </div>
                </div>
              </div>
              <div className="flex items-center pr-3">
                <ChevronRight className="w-5 h-5 text-gray-400" />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}