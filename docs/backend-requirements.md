# Backend Requirements for Courses & Profile

This document describes the API changes required for the mobile app’s course access and grade-based filtering.

---

## 1. Courses API

**Endpoint:** Existing courses list endpoint (e.g. `GET /courses`).

### Request (unchanged)

- `page`, `limit`, `category_id` (optional), `filters_levels` (optional).
- The app sends **`filters_levels`** with the student’s grade id (e.g. 17, 18, 19, 20, 21). Backend should filter courses by this when supported.

### Response – course object

Each course in the `data` array **must** include:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assigned_student_ids` | `string[]` | **Yes** | List of user IDs of students **manually assigned** to this course from the dashboard. If the logged-in user’s ID is not in this list, the app **does not show** the course at all (no card, no locked state, no preview). |
| `grade` | `number` | Optional | Grade/level id for this course (e.g. 17, 18, 19, 20, 21). Used so the app can ensure `course.grade == student.grade` when needed. |

**Example course object (relevant fields):**

```json
{
  "id": "123",
  "title": "Course Title",
  "assigned_student_ids": ["user_1", "user_2"],
  "grade": 17,
  ...
}
```

**Business rule:**  
- Paid courses must appear in the app **only** for students whose ID is in `assigned_student_ids`.  
- When an admin assigns a student to a course from the dashboard, that student’s user ID must be added to that course’s `assigned_student_ids`.

---

## 2. Profile / User API

**Endpoint:** Existing profile or user endpoint (e.g. `GET /users/me` or `GET /profile`).

### Response – user/profile object

Include the following field:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `grade` | `number` | Optional but recommended | Student’s grade/level id. Same scheme as course grade (e.g. 17 = الفرقة الأولى, 18 = الثانية, 19 = الثالثة, 20 = الرابعة, 21 = خريج). The app uses this for all grade-based filtering (courses, college, internship/emtyaz). |

**Example (inside `data` or user object):**

```json
{
  "id": "user_123",
  "full_name": "...",
  "grade": 17,
  ...
}
```

If `grade` is not returned, the app defaults to grade `17` until the backend provides it.

---

## 3. Grade IDs (reference)

| Value | Meaning (Arabic) |
|-------|-------------------|
| 17 | الفرقة الأولى |
| 18 | الفرقة الثانية |
| 19 | الفرقة الثالثة |
| 20 | الفرقة الرابعة |
| 21 | خريج |

---

## 4. Summary

| API | Field / behavior | Required |
|-----|-------------------|----------|
| **Courses list** | `assigned_student_ids` (array of user IDs) | **Yes** |
| **Courses list** | `grade` (number) per course | Optional |
| **Profile / user** | `grade` (number) for the student | Recommended |

**Minimum for correct behavior:**  
- Courses response includes **`assigned_student_ids`** for each course, and dashboard assignment updates this list.  
- Profile response includes **`grade`** for the logged-in user so the app can filter by student grade everywhere.
