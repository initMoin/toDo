# Contributing to toDō

First off, thank you for your interest in toDō! 

This repository exists to share architectural decisions, encourage technical discussion, and showcase the engineering behind the app. While toDō is a proprietary commercial product and **not open source**, I welcome community collaboration, bug reports, and code contributions that align with the project's goals.

Please read through these guidelines to ensure a smooth and productive collaboration.

## 📌 Repository Status

This repository contains the source code for the production version of toDō.

While community contributions are welcome, the project roadmap, feature direction, and release schedule are maintained by the author.

---

## ⚖️ Licensing

Please review the [LICENSE](LICENSE.md) file before contributing.

By submitting a Pull Request, you agree to the contribution terms described in the LICENSE.

---

## 🧭 Design Principles

Contributions are more likely to be accepted when they align with the project's guiding principles:

### Simplicity Before Features
toDō intentionally resists feature accumulation for its own sake. New functionality should reduce friction, improve clarity, or solve a specific problem. Features that increase complexity without creating meaningful value are unlikely to be adopted.

### Native Platform Experience
The application embraces Apple platform conventions rather than abstracting them away. Widgets, Live Activities, App Intents, and platform-specific interactions are considered first-class experiences.

### Structure Encourages Action
The goal is not to help users manage more tasks. The goal is to help users complete the tasks that matter. Design decisions should support clarity, momentum, and intentional action.

---

## 💻 Development Environment

Current development targets:

- Xcode 27 Beta
- Swift 6
- iOS 27
- iPadOS 27
- watchOS 27

Core technologies:

- SwiftUI
- SwiftData
- CloudKit
- Supabase
- StoreKit 2
- TipKit
- WidgetKit
- ActivityKit
- App Intents

---

## 🐛 Opening Issues

If you want to discuss the code, report a bug, or suggest an enhancement, the Issue Tracker is the place to do it.

### 1. Bug Reports
If you spot an issue, please check if it has already been reported. If not, open a new issue and include:
* A clear, descriptive title.
* Steps to reproduce the bug.
* Expected vs. actual behavior.
* The specific platform and OS version where the issue occurs.

### 2. Feature Requests
Because toDō is a minimalist, opinionated application, not every feature request will align with the product roadmap. However, I am always open to hearing ideas! Please provide:
* A clear description of the proposed feature.
* The specific problem it solves for the user.
* Any UI/UX considerations.

### 3. Architecture Discussions
Want to ask why a specific pattern was used, or how the data layer is structured? Feel free to open an issue tagged as a `question` or `discussion`. I am happy to chat about Swift, cross-platform development, and system design.

---

## 🛠️ Submitting Pull Requests

I appreciate PRs that fix bugs, improve performance, or enhance accessibility. For larger feature additions, please **open an issue first** to discuss the idea before spending time writing code.

### PR Guidelines
1. **Keep it Focused:** A PR should do one thing well. If you are fixing two unrelated bugs, please submit two separate PRs.
2. **Explain the "Why":** In your PR description, explain *why* the change is necessary and *how* you implemented it.
3. **Match the Style:** Please adhere to the existing Swift and SwiftUI coding conventions found in the project. Keep the code clean, readable, and well-organized.
4. **Test Locally:** Ensure your changes compile successfully and do not break existing functionality. If your change affects the UI, please test it across different device sizes and platforms where applicable.

---

Thank you for respecting the repository's licensing and for contributing to the conversation around toDō!