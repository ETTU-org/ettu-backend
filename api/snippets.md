# API Snippets Publics ETTU

## Vue d'ensemble

L'API Snippets Publics gère la banque de snippets communautaire d'ETTU, permettant aux utilisateurs de partager, découvrir et utiliser des snippets de code.

## Endpoints principaux

### Découverte des snippets

#### GET /api/snippets
Récupérer la liste des snippets publics.

```typescript
interface SnippetsResponse {
  snippets: PublicSnippet[];
  pagination: Pagination;
  filters: {
    languages: string[];
    categories: string[];
    tags: string[];
    difficulties: string[];
  };
}

interface PublicSnippet {
  id: string;
  title: string;
  description?: string;
  code: string;
  language: string;
  tags: string[];
  category?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  
  author: {
    id: string;
    username: string;
    displayName: string;
    reputation: number;
  };
  
  stats: {
    viewsCount: number;
    likesCount: number;
    forksCount: number;
    downloadsCount: number;
  };
  
  trendingScore: number;
  
  sourceType: 'original' | 'from_project' | 'fork';
  sourceProject?: {
    id: string;
    name: string;
  };
  
  moderationStatus: 'pending' | 'approved' | 'rejected' | 'flagged';
  isFeatured: boolean;
  
  createdAt: string;
  updatedAt: string;
}
```

**Paramètres de requête:**
- `language`: Filtrer par langage
- `category`: Filtrer par catégorie
- `tags`: Filtrer par tags (séparés par virgule)
- `difficulty`: Filtrer par difficulté
- `search`: Recherche dans titre/description/code
- `sort`: Tri (`trending`, `popular`, `recent`, `likes`)
- `featured`: Snippets mis en avant uniquement
- `author`: Filtrer par auteur
- `page`: Page (défaut: 1)
- `limit`: Limite par page (défaut: 20, max: 100)

#### GET /api/snippets/trending
Récupérer les snippets tendance.

```typescript
interface TrendingSnippetsResponse {
  snippets: PublicSnippet[];
  period: 'day' | 'week' | 'month';
  trendingFactors: {
    recentLikes: number;
    recentViews: number;
    recentForks: number;
    authorReputation: number;
  };
}
```

#### GET /api/snippets/featured
Récupérer les snippets mis en avant.

#### GET /api/snippets/categories
Récupérer les catégories disponibles.

```typescript
interface CategoriesResponse {
  categories: Category[];
}

interface Category {
  name: string;
  displayName: string;
  description: string;
  icon?: string;
  snippetCount: number;
  popularLanguages: string[];
}
```

### Détails des snippets

#### GET /api/snippets/{id}
Récupérer un snippet par son ID.

```typescript
interface SnippetDetailsResponse {
  snippet: PublicSnippet;
  author: {
    id: string;
    username: string;
    displayName: string;
    reputation: number;
    publicSnippetsCount: number;
    totalLikes: number;
    joinedAt: string;
  };
  relatedSnippets: PublicSnippet[];
  comments: Comment[];
  userInteraction?: {
    hasLiked: boolean;
    hasForked: boolean;
    hasDownloaded: boolean;
  };
}

interface Comment {
  id: string;
  content: string;
  author: {
    id: string;
    username: string;
    displayName: string;
    reputation: number;
  };
  parentId?: string;
  replies?: Comment[];
  likesCount: number;
  isEdited: boolean;
  createdAt: string;
  updatedAt: string;
}
```

#### POST /api/snippets/{id}/view
Enregistrer une vue sur un snippet.

#### GET /api/snippets/{id}/raw
Récupérer le code brut d'un snippet.

### Publications et gestion

#### POST /api/snippets
Publier un nouveau snippet.

```typescript
interface CreateSnippetRequest {
  title: string;
  description?: string;
  code: string;
  language: string;
  tags?: string[];
  category?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  
  // Optionnel si publié depuis un projet
  sourceType?: 'original' | 'from_project';
  sourceProjectId?: string;
  sourceSnippetId?: string;
}

interface CreateSnippetResponse {
  snippet: PublicSnippet;
  moderationStatus: 'pending' | 'approved';
  estimatedReviewTime?: string;
}
```

#### PUT /api/snippets/{id}
Mettre à jour un snippet (auteur uniquement).

```typescript
interface UpdateSnippetRequest {
  title?: string;
  description?: string;
  code?: string;
  tags?: string[];
  category?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  changeSummary?: string;
}
```

#### DELETE /api/snippets/{id}
Supprimer un snippet (auteur uniquement).

### Interactions sociales

#### POST /api/snippets/{id}/like
Aimer un snippet.

```typescript
interface LikeResponse {
  liked: boolean;
  likesCount: number;
}
```

#### DELETE /api/snippets/{id}/like
Retirer son like.

#### POST /api/snippets/{id}/fork
Forker un snippet.

```typescript
interface ForkRequest {
  targetType: 'public' | 'project';
  projectId?: string; // Si targetType = 'project'
  title?: string;
  description?: string;
  modifications?: string; // Description des modifications
}

interface ForkResponse {
  fork: PublicSnippet | ProjectSnippet;
  forkRelation: {
    id: string;
    originalSnippetId: string;
    forkSnippetId: string;
    createdAt: string;
  };
}
```

#### GET /api/snippets/{id}/forks
Récupérer la liste des forks d'un snippet.

```typescript
interface ForksResponse {
  forks: Fork[];
  pagination: Pagination;
}

interface Fork {
  id: string;
  title: string;
  author: {
    id: string;
    username: string;
    displayName: string;
  };
  type: 'public' | 'project';
  project?: {
    id: string;
    name: string;
  };
  likesCount: number;
  createdAt: string;
}
```

#### POST /api/snippets/{id}/download
Télécharger un snippet.

```typescript
interface DownloadResponse {
  downloadUrl: string;
  filename: string;
  expiresAt: string;
}
```

### Commentaires

#### GET /api/snippets/{id}/comments
Récupérer les commentaires d'un snippet.

```typescript
interface CommentsResponse {
  comments: Comment[];
  pagination: Pagination;
  totalCount: number;
}
```

#### POST /api/snippets/{id}/comments
Ajouter un commentaire.

```typescript
interface CreateCommentRequest {
  content: string;
  parentId?: string; // Pour les réponses
}

interface CreateCommentResponse {
  comment: Comment;
}
```

#### PUT /api/snippets/{id}/comments/{commentId}
Modifier un commentaire.

#### DELETE /api/snippets/{id}/comments/{commentId}
Supprimer un commentaire.

#### POST /api/snippets/{id}/comments/{commentId}/like
Aimer un commentaire.

### Recherche avancée

#### GET /api/snippets/search
Recherche avancée dans les snippets.

```typescript
interface SearchRequest {
  query: string;
  language?: string;
  category?: string;
  tags?: string[];
  difficulty?: string;
  author?: string;
  dateFrom?: string;
  dateTo?: string;
  minLikes?: number;
  codeSearch?: boolean; // Recherche dans le code
  regex?: boolean; // Recherche regex
}

interface SearchResponse {
  snippets: PublicSnippet[];
  pagination: Pagination;
  searchStats: {
    totalResults: number;
    searchTime: number;
    suggestions?: string[];
  };
  aggregations: {
    languages: { [key: string]: number };
    categories: { [key: string]: number };
    tags: { [key: string]: number };
  };
}
```

### Signalement et modération

#### POST /api/snippets/{id}/report
Signaler un snippet.

```typescript
interface ReportRequest {
  reason: 'spam' | 'inappropriate' | 'copyright' | 'security' | 'misleading' | 'other';
  description?: string;
  details?: {
    urls?: string[];
    evidence?: string;
  };
}

interface ReportResponse {
  report: {
    id: string;
    status: 'pending';
    submittedAt: string;
  };
  message: string;
}
```

#### GET /api/snippets/{id}/reports
Récupérer les signalements d'un snippet (modérateurs uniquement).

### Collections et favoris

#### GET /api/snippets/favorites
Récupérer les snippets favoris de l'utilisateur.

```typescript
interface FavoritesResponse {
  favorites: PublicSnippet[];
  pagination: Pagination;
}
```

#### POST /api/snippets/{id}/favorite
Ajouter aux favoris.

#### DELETE /api/snippets/{id}/favorite
Retirer des favoris.

#### GET /api/snippets/collections
Récupérer les collections de snippets.

```typescript
interface CollectionsResponse {
  collections: Collection[];
  pagination: Pagination;
}

interface Collection {
  id: string;
  name: string;
  description?: string;
  isPublic: boolean;
  snippetsCount: number;
  author: {
    id: string;
    username: string;
    displayName: string;
  };
  tags: string[];
  createdAt: string;
  updatedAt: string;
}
```

#### POST /api/snippets/collections
Créer une collection.

```typescript
interface CreateCollectionRequest {
  name: string;
  description?: string;
  isPublic?: boolean;
  tags?: string[];
}
```

#### POST /api/snippets/collections/{collectionId}/snippets
Ajouter un snippet à une collection.

```typescript
interface AddToCollectionRequest {
  snippetId: string;
  note?: string;
}
```

### Historique et versions

#### GET /api/snippets/{id}/history
Récupérer l'historique des modifications.

```typescript
interface SnippetHistoryResponse {
  history: SnippetVersion[];
  pagination: Pagination;
}

interface SnippetVersion {
  id: string;
  versionNumber: number;
  title: string;
  description?: string;
  code: string;
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

#### GET /api/snippets/{id}/versions/{versionId}
Récupérer une version spécifique.

#### POST /api/snippets/{id}/versions/{versionId}/restore
Restaurer à une version précédente.

### Statistiques et analytics

#### GET /api/snippets/{id}/stats
Récupérer les statistiques détaillées d'un snippet.

```typescript
interface SnippetStatsResponse {
  stats: {
    views: {
      total: number;
      daily: { date: string; count: number }[];
      weekly: { week: string; count: number }[];
      monthly: { month: string; count: number }[];
    };
    likes: {
      total: number;
      daily: { date: string; count: number }[];
    };
    forks: {
      total: number;
      public: number;
      private: number;
    };
    downloads: {
      total: number;
      daily: { date: string; count: number }[];
    };
    geography: {
      country: string;
      count: number;
    }[];
  };
}
```

#### GET /api/snippets/my-snippets
Récupérer les snippets de l'utilisateur connecté.

```typescript
interface MySnippetsResponse {
  snippets: PublicSnippet[];
  pagination: Pagination;
  totalStats: {
    totalSnippets: number;
    totalViews: number;
    totalLikes: number;
    totalForks: number;
    totalDownloads: number;
  };
}
```

### Import/Export

#### POST /api/snippets/import
Importer des snippets depuis différentes sources.

```typescript
interface ImportRequest {
  source: 'gist' | 'codepen' | 'jsbin' | 'file';
  data: {
    url?: string;
    content?: string;
    language?: string;
    metadata?: {
      title?: string;
      description?: string;
      tags?: string[];
    };
  };
}

interface ImportResponse {
  snippets: PublicSnippet[];
  errors?: string[];
}
```

#### GET /api/snippets/export
Exporter les snippets de l'utilisateur.

```typescript
interface ExportRequest {
  format: 'json' | 'zip' | 'gist';
  filter?: {
    language?: string;
    category?: string;
    dateFrom?: string;
    dateTo?: string;
  };
}

interface ExportResponse {
  downloadUrl: string;
  filename: string;
  expiresAt: string;
}
```

## Gestion des erreurs

### Codes d'erreur spécifiques

```typescript
const SNIPPET_ERRORS = {
  SNIPPET_NOT_FOUND: 'Snippet non trouvé',
  SNIPPET_NOT_APPROVED: 'Snippet non approuvé',
  INSUFFICIENT_PERMISSIONS: 'Permissions insuffisantes',
  ALREADY_LIKED: 'Snippet déjà aimé',
  CANNOT_LIKE_OWN_SNIPPET: 'Impossible d\'aimer son propre snippet',
  FORK_LIMIT_EXCEEDED: 'Limite de forks atteinte',
  INVALID_LANGUAGE: 'Langage non supporté',
  CODE_TOO_LARGE: 'Code trop volumineux',
  DUPLICATE_SNIPPET: 'Snippet similaire déjà existant',
  MODERATION_REQUIRED: 'Snippet en attente de modération',
  RATE_LIMIT_EXCEEDED: 'Limite de taux dépassée',
};
```

## Middleware et sécurité

### Authentification
- Endpoints publics: `GET /api/snippets`, `GET /api/snippets/{id}`, `GET /api/snippets/categories`
- Endpoints privés: Actions sur les snippets (like, fork, comment, etc.)

### Permissions
- **Publier**: Utilisateurs enregistrés uniquement
- **Modifier**: Auteur uniquement
- **Supprimer**: Auteur ou modérateur
- **Modérer**: Modérateurs uniquement

### Rate limiting
- Recherche: 100 req/min
- Publication: 10 snippets/jour
- Likes: 200/heure
- Commentaires: 50/heure
- Téléchargements: 100/heure

### Validation
- Titre: 3-200 caractères
- Description: max 1000 caractères
- Code: max 100KB
- Tags: max 10, 2-30 caractères chacun

## Exemples d'utilisation

### Recherche et découverte

```typescript
// Recherche par langage et difficulté
const snippets = await searchSnippets({
  language: 'javascript',
  difficulty: 'intermediate',
  tags: ['react', 'hooks'],
  sort: 'trending'
});

// Obtenir les snippets tendance
const trending = await getTrendingSnippets({
  period: 'week',
  limit: 10
});
```

### Interaction avec les snippets

```typescript
// Aimer un snippet
await likeSnippet(snippetId);

// Forker vers un projet
const fork = await forkSnippet(snippetId, {
  targetType: 'project',
  projectId: myProjectId,
  title: 'Version modifiée'
});

// Commenter
await addComment(snippetId, {
  content: 'Excellent snippet ! 👍',
  parentId: null
});
```

### Gestion des snippets

```typescript
// Publier un snippet
const snippet = await createSnippet({
  title: 'Hook React personnalisé',
  description: 'Un hook pour gérer les données async',
  code: 'const useAsync = (asyncFn) => { ... }',
  language: 'javascript',
  category: 'hooks',
  difficulty: 'intermediate',
  tags: ['react', 'hooks', 'async']
});

// Suivre les statistiques
const stats = await getSnippetStats(snippetId);
console.log(`${stats.views.total} vues, ${stats.likes.total} likes`);
```
