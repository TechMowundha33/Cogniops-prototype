# CogniOps — AI Teammate for Cloud Builders

A complete, production-ready **Flutter** application for learning and building with cloud technologies.

## 🚀 Quick Start

```bash
flutter pub get
flutter run
```
## Tech Stack
```
Frontend: Flutter
Backend: AWS Lambda
AI: Amazon Bedrock (Claude)
Auth: Amazon Cognito
Database: DynamoDB
Hosting: Amazon S3
```

## 📁 Project Structure

```
lib/
├── main.dart                     # App entry + AuthGate
├── core/
│   └── theme.dart                # AppTheme, AppColors (dark + light)
├── models/
│   ├── user_model.dart           # UserModel (role-locked at registration)
│   └── chat_message.dart        # ChatMessage
├── providers/
│   ├── auth_provider.dart        # Auth state + SharedPreferences session
│   ├── theme_provider.dart       # Dark/light toggle
│   └── chat_provider.dart        # Chat state + mock AI replies
├── screens/
│   ├── app_shell.dart            # Main scaffold: sidebar (desktop) + bottom nav (mobile)
│   ├── settings_screen.dart      # Profile, theme, preferences, sign-out
│   ├── auth/
│   │   ├── login_screen.dart     # Login with gradient glow bg
│   │   └── register_screen.dart  # Register + role selection cards (locked)
│   ├── student/
│   │   ├── student_dashboard.dart  # XP, streak, progress bars, activity feed
│   │   ├── chat_screen.dart       # AI chat with typing indicator, voice btn
│   │   ├── roadmap_screen.dart    # 3-stage: input → confirm → 12-week timeline
│   │   ├── concept_screen.dart    # Voice input, AI sections, flip flashcards
│   │   ├── quiz_screen.dart       # Difficulty, 30s countdown, XP rewards
│   │   └── progress_screen.dart   # Bar chart, XP level, achievement badges
│   └── developer/
│       ├── dev_dashboard.dart      # Deployment status, tool cards
│       ├── architecture_screen.dart # App → AWS architecture + Terraform + cost tabs
│       ├── backend_designer_screen.dart # Code → Lambda/API/DynamoDB suggestions
│       ├── terraform_screen.dart   # Description → production Terraform code
│       ├── cost_estimator_screen.dart # Service breakdown + optimization suggestions
│       └── debug_screen.dart       # Socratic debugging multi-turn chat
└── widgets/
    ├── common_widgets.dart        # GradientButton, AppCard, AppAvatar, StatCard, CodeBlock...
    └── floating_assistant.dart    # Quick-Ask FAB with expandable chat overlay
```

## ✨ Features

### 🎓 Student Mode (7 screens)
| Screen | Features |
|---|---|
| Dashboard | XP system, 7-day streak, progress bars, recent activity |
| AI Chat | Typing indicator, voice icon, copy/regenerate, animated dots |
| Roadmap | Input → AI confirmation → 12-week expandable timeline |
| Concept Explainer | Topic input, voice, 4 AI sections, flip flashcards |
| Smart Quiz | Easy/Moderate/Hard, 30s countdown, XP rewards, results |
| Progress | Bar chart, XP level bar, achievement badges |
| Settings | Profile, theme toggle, preferences, locked role indicator |

### 💻 Developer Mode (8 screens)
| Screen | Features |
|---|---|
| Dashboard | Deployment status (Prod/Staging/Dev), tool grid, counters |
| AI Chat | Dev-focused responses, architect-mode personality |
| Architecture Generator | App idea → 8 AWS services + Terraform tab + cost tab |
| Backend Designer | Code paste → service suggestions, Lambda config, API routes |
| Terraform Generator | Description → production-ready Terraform with VPC/ECS/ALB |
| Cost Estimator | 7 services breakdown, high-cost warnings, optimization tips |
| Socratic Debug | Multi-turn guided debugging session |
| Settings | Same as student |

## 🎨 Design System

| Token | Dark | Light |
|---|---|---|
| Background | `#0A0B0F` | `#F4F5FB` |
| Surface | `#12141A` | `#FFFFFF` |
| Accent (primary) | `#6C63FF` | same |
| Accent Alt (pink) | `#FF6584` | same |
| Green | `#00D4A1` | same |
| Amber | `#FFB347` | same |

**Fonts:** DM Sans (body), Space Mono (code/numbers)

## 🔗 Production Integration Checklist
- [ ] Replace `Future.delayed` mock delays with real Anthropic/AWS Bedrock API calls
- [ ] Connect `speech_to_text` Flutter plugin for voice input
- [ ] Add AWS Cognito SDK for real authentication
- [ ] Integrate Terraform diagram rendering (Mermaid or custom SVG)
- [ ] Add real D3/AWS architecture diagram widget
- [ ] Connect to real AWS Pricing API for cost estimator
- [ ] Enable push notifications for streaks and reminders

## 📦 Dependencies

```yaml
provider: ^6.1.1           # State management
shared_preferences: ^2.2.2 # Local session persistence
google_fonts: ^6.1.0       # DM Sans, Space Mono
fl_chart: ^0.66.0          # Chart widgets
http: ^1.1.0               # API calls
```

---
Built with ❤️ for cloud engineers and learners worldwide.
