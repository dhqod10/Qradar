import { NavLink } from "react-router";
import { Home, Receipt, Menu } from "lucide-react";
import { motion } from "motion/react";
import { QradarLogo } from "./QradarLogo";

export function BottomNav() {
  const navItems = [
    { to: "/", icon: Home, label: "홈" },
    { to: "/qoin", icon: null, label: "Qoin", isQoin: true },
    { to: "/order", icon: null, label: "주문", isCenter: true },
    { to: "/history", icon: Receipt, label: "주문내역" },
    { to: "/more", icon: Menu, label: "더보기" },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-lg z-50">
      <div className="grid grid-cols-5 max-w-2xl mx-auto relative">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === "/"}
            className={({ isActive }) =>
              `flex flex-col items-center gap-1 py-3 transition-colors ${
                item.isCenter ? "" : ""
              }`
            }
          >
            {({ isActive }) => (
              <>
                {item.isCenter ? (
                  <>
                    <motion.div
                      className="w-14 h-14 -mt-7 mb-1 rounded-full flex items-center justify-center shadow-xl transition-all cursor-pointer"
                      style={{
                        background: "linear-gradient(to bottom right, #0f172a, #1e293b)"
                      }}
                      animate={{
                        boxShadow: [
                          "0 0 0 0px rgba(15, 23, 42, 0.9)",
                          "0 0 0 6px rgba(15, 23, 42, 0.5)",
                          "0 0 0 0px rgba(15, 23, 42, 0.9)",
                        ],
                      }}
                      whileHover={{
                        scale: 1.1,
                        y: -4,
                      }}
                      whileTap={{
                        scale: 0.95,
                        rotate: [0, -5, 5, 0],
                      }}
                      transition={{
                        duration: 2,
                        repeat: Infinity,
                        ease: "easeInOut",
                      }}
                    >
                      <CoffeeCupIcon isActive={isActive} />
                    </motion.div>
                    <span className={`text-xs font-medium ${isActive ? "text-slate-900" : "text-gray-600"}`}>
                      {item.label}
                    </span>
                  </>
                ) : item.isQoin ? (
                  <>
                    <div className="w-6 h-6 flex items-center justify-center">
                      <QradarLogo
                        size={24}
                        color={isActive ? "#0f172a" : "#9ca3af"}
                        showText={false}
                      />
                    </div>
                    <span className={`text-xs font-medium ${isActive ? "text-slate-900" : "text-gray-400"}`}>
                      {item.label}
                    </span>
                  </>
                ) : (
                  <>
                    <item.icon
                      className={`w-6 h-6 transition-all ${
                        isActive
                          ? "text-slate-900 fill-none stroke-slate-900"
                          : "text-gray-400 fill-none stroke-gray-400"
                      }`}
                      strokeWidth={2}
                    />
                    <span className={`text-xs font-medium ${isActive ? "text-slate-900" : "text-gray-400"}`}>
                      {item.label}
                    </span>
                  </>
                )}
              </>
            )}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}

function CoffeeCupIcon({ isActive }: { isActive: boolean }) {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* 커피 컵 - 채워진 스타일 */}
      <path
        d="M5 9h14v8c0 1.5-1.5 3-3 3H8c-1.5 0-3-1.5-3-3V9z"
        fill="white"
        stroke="white"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {/* 컵 윗부분 강조 */}
      <path
        d="M4 9h16"
        stroke="white"
        strokeWidth="2"
        strokeLinecap="round"
      />
      {/* 손잡이 */}
      <path
        d="M19 11v2c0 1 .5 2 1.5 2s1.5-1 1.5-2v-1c0-1-.5-2-1.5-2H19"
        stroke="white"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
      {/* 김 효과 - 왼쪽 (애니메이션) */}
      <motion.path
        d="M8 7C8 5 8.5 3.5 9 2"
        stroke="white"
        strokeWidth="2"
        strokeLinecap="round"
        initial={{ opacity: 0.3 }}
        animate={{
          y: [0, -1, 0],
          x: [0, 0.5, -0.5, 0],
          opacity: [0.3, 0.8, 0.3],
        }}
        transition={{
          duration: 2.5,
          repeat: Infinity,
          ease: "easeInOut",
          delay: 0,
        }}
      />
      {/* 김 효과 - 가운데 (애니메이션) */}
      <motion.path
        d="M12 7C12 4.5 12.5 3 13 1"
        stroke="white"
        strokeWidth="2"
        strokeLinecap="round"
        initial={{ opacity: 0.4 }}
        animate={{
          y: [0, -1.5, 0],
          x: [0, -0.5, 0.5, 0],
          opacity: [0.4, 0.9, 0.4],
        }}
        transition={{
          duration: 2.5,
          repeat: Infinity,
          ease: "easeInOut",
          delay: 0.4,
        }}
      />
      {/* 김 효과 - 오른쪽 (애니메이션) */}
      <motion.path
        d="M16 7C16 5 16.5 3.5 17 2"
        stroke="white"
        strokeWidth="2"
        strokeLinecap="round"
        initial={{ opacity: 0.3 }}
        animate={{
          y: [0, -1, 0],
          x: [0, -0.5, 0.5, 0],
          opacity: [0.3, 0.8, 0.3],
        }}
        transition={{
          duration: 2.5,
          repeat: Infinity,
          ease: "easeInOut",
          delay: 0.8,
        }}
      />
    </svg>
  );
}