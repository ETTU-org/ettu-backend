# API Projets ETTU

## Vue d'ensemble

L'API Projets gère la création, modification et collaboration sur les projets dans ETTU.

## Endpoints principaux

### Projets

#### GET /api/projects
Récupérer la liste des projets accessibles à l'utilisateur.

```typescript
interface ProjectListResponse {
  projects: Project[];
  pagination: {
    total: number;
    page: number;
    limit: number;
    hasMore: boolean;
  };
}

interface Project {
  id: string;
  name: string;
  description: string;
  color: string;
  status: 'active' | 'paused' | 'completed' | 'archived';
  visibility: 'private' | 'team' | 'public';
  isTemplate: boolean;
  
  owner: {
    id: string;
    username: string;
    displayName: string;
  };
  
  stats: {
    totalNotes: number;
    totalSnippets: number;
    totalTasks: number;
    completedTasks: number;
    membersCount: number;
    lastActivity: string;
  };
  
  userRole: 'owner' | 'admin' | 'editor' | 'viewer';
  permissions: ProjectPermissions;
  
  createdAt: string;
  updatedAt: string;
}

interface ProjectPermissions {
  canEditProject: boolean;
  canManageMembers: boolean;
  canCreateNotes: boolean;
  canEditNotes: boolean;
  canDeleteNotes: boolean;
  canCreateSnippets: boolean;
  canEditSnippets: boolean;
  canDeleteSnippets: boolean;
  canCreateTasks: boolean;
  canEditTasks: boolean;
  canDeleteTasks: boolean;
}
```

**Paramètres de requête:**
- `status`: Filtrer par statut
- `visibility`: Filtrer par visibilité
- `search`: Recherche dans nom/description
- `sort`: Tri (`name`, `created_at`, `updated_at`, `last_activity`)
- `page`: Page (défaut: 1)
- `limit`: Limite par page (défaut: 20, max: 100)

#### POST /api/projects
Créer un nouveau projet.

```typescript
interface CreateProjectRequest {
  name: string;
  description?: string;
  color: string;
  visibility: 'private' | 'team' | 'public';
  isTemplate?: boolean;
  templateCategory?: string;
  technologies?: string[];
  settings?: {
    allowPublicSharing: boolean;
    enableDiscussions: boolean;
  };
}

interface CreateProjectResponse {
  project: Project;
}
```

#### GET /api/projects/{id}
Récupérer un projet par son ID.

```typescript
interface ProjectDetailsResponse {
  project: Project;
  members: ProjectMember[];
  recentActivity: ActivityItem[];
}

interface ProjectMember {
  id: string;
  username: string;
  displayName: string;
  role: 'owner' | 'admin' | 'editor' | 'viewer';
  permissions: ProjectPermissions;
  joinedAt: string;
  lastActivity: string;
}

interface ActivityItem {
  id: string;
  type: 'note_created' | 'snippet_added' | 'task_completed' | 'member_joined';
  user: {
    id: string;
    username: string;
    displayName: string;
  };
  entity?: {
    id: string;
    type: 'note' | 'snippet' | 'task';
    title: string;
  };
  timestamp: string;
}
```

#### PUT /api/projects/{id}
Mettre à jour un projet.

```typescript
interface UpdateProjectRequest {
  name?: string;
  description?: string;
  color?: string;
  status?: 'active' | 'paused' | 'completed' | 'archived';
  visibility?: 'private' | 'team' | 'public';
  technologies?: string[];
  settings?: {
    allowPublicSharing?: boolean;
    enableDiscussions?: boolean;
  };
}
```

#### DELETE /api/projects/{id}
Supprimer un projet (propriétaire uniquement).

### Membres du projet

#### GET /api/projects/{id}/members
Récupérer la liste des membres du projet.

#### POST /api/projects/{id}/members
Inviter un membre au projet.

```typescript
interface InviteMemberRequest {
  email?: string;
  username?: string;
  role: 'admin' | 'editor' | 'viewer';
  permissions?: Partial<ProjectPermissions>;
}

interface InviteMemberResponse {
  invitation: {
    id: string;
    email: string;
    role: string;
    invitedBy: string;
    invitedAt: string;
    expiresAt: string;
  };
}
```

#### PUT /api/projects/{id}/members/{userId}
Modifier le rôle ou les permissions d'un membre.

```typescript
interface UpdateMemberRequest {
  role?: 'admin' | 'editor' | 'viewer';
  permissions?: Partial<ProjectPermissions>;
}
```

#### DELETE /api/projects/{id}/members/{userId}
Retirer un membre du projet.

### Notes du projet

#### GET /api/projects/{id}/notes
Récupérer les notes du projet.

```typescript
interface ProjectNotesResponse {
  notes: ProjectNote[];
  pagination: Pagination;
}

interface ProjectNote {
  id: string;
  title: string;
  content: string;
  type: 'brief' | 'analysis' | 'documentation' | 'research' | 'meeting' | 'idea';
  tags: string[];
  folder?: string;
  isPinned: boolean;
  isArchived: boolean;
  
  author: {
    id: string;
    username: string;
    displayName: string;
  };
  
  lastEditedBy?: {
    id: string;
    username: string;
    displayName: string;
  };
  
  version: number;
  createdAt: string;
  updatedAt: string;
}
```

#### POST /api/projects/{id}/notes
Créer une nouvelle note.

```typescript
interface CreateNoteRequest {
  title: string;
  content: string;
  type: 'brief' | 'analysis' | 'documentation' | 'research' | 'meeting' | 'idea';
  tags?: string[];
  folder?: string;
  isPinned?: boolean;
}
```

#### PUT /api/projects/{id}/notes/{noteId}
Mettre à jour une note.

#### DELETE /api/projects/{id}/notes/{noteId}
Supprimer une note.

### Snippets du projet

#### GET /api/projects/{id}/snippets
Récupérer les snippets du projet.

```typescript
interface ProjectSnippetsResponse {
  snippets: ProjectSnippet[];
  pagination: Pagination;
}

interface ProjectSnippet {
  id: string;
  title: string;
  description?: string;
  code: string;
  language: string;
  type: 'function' | 'component' | 'hook' | 'utility' | 'config' | 'template';
  tags: string[];
  folder?: string;
  isPinned: boolean;
  isArchived: boolean;
  isPublic: boolean;
  
  author: {
    id: string;
    username: string;
    displayName: string;
  };
  
  dependencies: string[];
  usageExample?: string;
  version: number;
  
  createdAt: string;
  updatedAt: string;
}
```

#### POST /api/projects/{id}/snippets
Créer un nouveau snippet.

```typescript
interface CreateSnippetRequest {
  title: string;
  description?: string;
  code: string;
  language: string;
  type: 'function' | 'component' | 'hook' | 'utility' | 'config' | 'template';
  tags?: string[];
  folder?: string;
  dependencies?: string[];
  usageExample?: string;
}
```

#### PUT /api/projects/{id}/snippets/{snippetId}
Mettre à jour un snippet.

#### DELETE /api/projects/{id}/snippets/{snippetId}
Supprimer un snippet.

#### POST /api/projects/{id}/snippets/{snippetId}/publish
Publier un snippet dans la banque publique.

```typescript
interface PublishSnippetRequest {
  category?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  makePublic?: boolean;
}
```

### Tâches du projet

#### GET /api/projects/{id}/tasks
Récupérer les tâches du projet.

```typescript
interface ProjectTasksResponse {
  tasks: ProjectTask[];
  pagination: Pagination;
}

interface ProjectTask {
  id: string;
  title: string;
  description?: string;
  type: 'feature' | 'bug' | 'refactor' | 'documentation' | 'test' | 'idea';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  status: 'backlog' | 'in-progress' | 'testing' | 'done';
  tags: string[];
  
  author: {
    id: string;
    username: string;
    displayName: string;
  };
  
  assignee?: {
    id: string;
    username: string;
    displayName: string;
  };
  
  estimatedTime?: number; // en minutes
  actualTime?: number; // en minutes
  dueDate?: string;
  completedAt?: string;
  
  orderPosition: number;
  
  checklistItems: ChecklistItem[];
  relatedNotes: string[];
  relatedSnippets: string[];
  
  createdAt: string;
  updatedAt: string;
}

interface ChecklistItem {
  id: string;
  text: string;
  completed: boolean;
  orderPosition: number;
}
```

#### POST /api/projects/{id}/tasks
Créer une nouvelle tâche.

```typescript
interface CreateTaskRequest {
  title: string;
  description?: string;
  type: 'feature' | 'bug' | 'refactor' | 'documentation' | 'test' | 'idea';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  assigneeId?: string;
  estimatedTime?: number;
  dueDate?: string;
  tags?: string[];
  checklistItems?: Omit<ChecklistItem, 'id'>[];
}
```

#### PUT /api/projects/{id}/tasks/{taskId}
Mettre à jour une tâche.

#### DELETE /api/projects/{id}/tasks/{taskId}
Supprimer une tâche.

#### PUT /api/projects/{id}/tasks/{taskId}/status
Changer le statut d'une tâche.

```typescript
interface UpdateTaskStatusRequest {
  status: 'backlog' | 'in-progress' | 'testing' | 'done';
  actualTime?: number;
  completedAt?: string;
}
```

### Historique et versioning

#### GET /api/projects/{id}/history
Récupérer l'historique des modifications du projet.

```typescript
interface ProjectHistoryResponse {
  history: HistoryItem[];
  pagination: Pagination;
}

interface HistoryItem {
  id: string;
  entityType: 'project' | 'note' | 'snippet' | 'task';
  entityId: string;
  action: 'create' | 'update' | 'delete';
  user: {
    id: string;
    username: string;
    displayName: string;
  };
  changes: {
    field: string;
    oldValue: any;
    newValue: any;
  }[];
  timestamp: string;
}
```

#### GET /api/projects/{id}/notes/{noteId}/versions
Récupérer les versions d'une note.

```typescript
interface NoteVersionsResponse {
  versions: NoteVersion[];
}

interface NoteVersion {
  id: string;
  versionNumber: number;
  title: string;
  content: string;
  changeSummary?: string;
  author: {
    id: string;
    username: string;
    displayName: string;
  };
  isMajor: boolean;
  createdAt: string;
}
```

#### POST /api/projects/{id}/notes/{noteId}/restore/{versionId}
Restaurer une note à une version précédente.

### Collaboration temps réel

#### WebSocket /api/projects/{id}/ws
Connexion WebSocket pour la collaboration en temps réel.

```typescript
interface WebSocketMessage {
  type: 'project_updated' | 'note_added' | 'task_status_changed' | 'user_joined' | 'user_left';
  data: any;
  timestamp: string;
}

// Exemples de messages
interface ProjectUpdatedMessage {
  type: 'project_updated';
  data: {
    projectId: string;
    changes: {
      field: string;
      oldValue: any;
      newValue: any;
    }[];
    updatedBy: {
      id: string;
      username: string;
      displayName: string;
    };
  };
}

interface NoteAddedMessage {
  type: 'note_added';
  data: {
    projectId: string;
    note: ProjectNote;
    addedBy: {
      id: string;
      username: string;
      displayName: string;
    };
  };
}
```

## Gestion des erreurs

### Codes d'erreur spécifiques

```typescript
interface ApiError {
  code: string;
  message: string;
  details?: any;
}

// Erreurs courantes
const PROJECT_ERRORS = {
  PROJECT_NOT_FOUND: 'Le projet demandé n\'existe pas',
  INSUFFICIENT_PERMISSIONS: 'Permissions insuffisantes pour cette action',
  PROJECT_LIMIT_EXCEEDED: 'Limite de projets atteinte',
  INVALID_PROJECT_DATA: 'Données du projet invalides',
  DUPLICATE_PROJECT_NAME: 'Un projet avec ce nom existe déjà',
  MEMBER_ALREADY_EXISTS: 'Ce membre fait déjà partie du projet',
  CANNOT_REMOVE_OWNER: 'Impossible de retirer le propriétaire',
  TEMPLATE_NOT_FOUND: 'Template de projet non trouvé',
};
```

## Middleware et sécurité

### Authentification requise
Tous les endpoints nécessitent une authentification (JWT token).

### Permissions par endpoint
- **GET /api/projects**: Accessible à tous les utilisateurs authentifiés
- **POST /api/projects**: Nécessite la permission `create_projects`
- **PUT /api/projects/{id}**: Nécessite la permission `can_edit_project` sur le projet
- **DELETE /api/projects/{id}**: Propriétaire uniquement

### Rate limiting
- Création de projets: 10 par heure
- Invitation de membres: 50 par heure
- Modifications: 100 par heure

### Validation des données
- Nom du projet: 3-255 caractères
- Description: max 2000 caractères
- Couleur: format hexadécimal valide
- Technologies: max 20 éléments

## Exemples d'utilisation

### Créer un projet avec des données initiales

```typescript
// 1. Créer le projet
const project = await createProject({
  name: 'Mon super projet',
  description: 'Description du projet',
  color: '#3b82f6',
  visibility: 'private',
  technologies: ['React', 'TypeScript', 'Node.js']
});

// 2. Ajouter une note initiale
await createNote(project.id, {
  title: 'Idées initiales',
  content: 'Contenu de la note...',
  type: 'idea',
  tags: ['brainstorming']
});

// 3. Créer les premières tâches
await createTask(project.id, {
  title: 'Configurer l\'environnement',
  type: 'feature',
  priority: 'high',
  status: 'backlog'
});
```

### Gérer les membres

```typescript
// Inviter un membre
const invitation = await inviteMember(projectId, {
  email: 'membre@example.com',
  role: 'editor'
});

// Modifier les permissions
await updateMember(projectId, memberId, {
  permissions: {
    canCreateNotes: true,
    canEditNotes: true,
    canDeleteNotes: false
  }
});
```

### Collaboration temps réel

```typescript
// Connexion WebSocket
const ws = new WebSocket(`ws://localhost:3000/api/projects/${projectId}/ws`);

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  
  switch (message.type) {
    case 'note_added':
      // Mettre à jour l'interface
      addNoteToUI(message.data.note);
      break;
    case 'task_status_changed':
      // Mettre à jour le statut de la tâche
      updateTaskStatus(message.data.taskId, message.data.newStatus);
      break;
  }
};
```
