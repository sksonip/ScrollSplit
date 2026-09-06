.PHONY: app build test clean

app:
	sh scripts/build-app.sh

build:
	CONFIGURATION=debug sh scripts/build-app.sh

test:
	mkdir -p "$(CURDIR)/.build/ModuleCache" "$(CURDIR)/.build/tests"
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/ModuleCache" xcrun swiftc -parse-as-library -target "$$(uname -m)-apple-macosx13.0" Sources/ScrollSplit/Scrolling/ScrollSourceClassifier.swift Tests/Smoke/ClassifierSmoke.swift -o "$(CURDIR)/.build/tests/ClassifierSmoke"
	"$(CURDIR)/.build/tests/ClassifierSmoke"
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/ModuleCache" xcrun swiftc -parse-as-library -target "$$(uname -m)-apple-macosx13.0" -framework AppKit -framework ApplicationServices -framework CoreGraphics -framework ServiceManagement Sources/ScrollSplit/App/ApplicationLaunchContext.swift Sources/ScrollSplit/App/ReverseScrollingController.swift Sources/ScrollSplit/Settings/AppSettings.swift Sources/ScrollSplit/Scrolling/ScrollSourceClassifier.swift Sources/ScrollSplit/Scrolling/ScrollEventTap.swift Sources/ScrollSplit/Services/PermissionService.swift Sources/ScrollSplit/Services/LoginItemService.swift Tests/Smoke/RuntimeStateSmoke.swift -o "$(CURDIR)/.build/tests/RuntimeStateSmoke"
	"$(CURDIR)/.build/tests/RuntimeStateSmoke"

clean:
	swift package clean
