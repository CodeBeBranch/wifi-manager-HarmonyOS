export type Hm6MapState = 'READY' | 'NO_DATA' | 'PERMISSION_DENIED' | 'LOW_ACCURACY'
export type Hm6GisMode = 'TRACK' | 'STAY' | 'HEAT' | 'COVERAGE'
export type Hm6GeofenceShape = 'CIRCLE' | 'POLYGON'
export type Hm6GeofenceEventType = 'ENTER' | 'EXIT'

export interface TenantLocation {
  id: number
  subjectId: string
  subjectName: string
  subjectType: 'MEMBER' | 'DEVICE'
  zoneName: string
  latitude: number
  longitude: number
  accuracyMeters: number
  capturedAt: string
}

export interface TenantTrackPoint {
  id: number
  sequence: number
  latitude: number
  longitude: number
  zoneName: string
  capturedAt: string
}

export interface TenantStayPoint {
  id: number
  zoneName: string
  durationMinutes: number
  latitude: number
  longitude: number
  startedAt: string
}

export interface TenantHeatPoint {
  id: number
  zoneName: string
  intensity: number
  latitude: number
  longitude: number
}

export interface TenantCoverageNode {
  id: number
  nodeName: string
  zoneName: string
  clientCount: number
  averageRssi: number
  latitude: number
  longitude: number
}

export interface TenantGisSnapshot {
  state: Hm6MapState
  accuracyMeters: number
  track: TenantTrackPoint[]
  stays: TenantStayPoint[]
  heat: TenantHeatPoint[]
  coverage: TenantCoverageNode[]
}

export interface TenantGeofence {
  id: number
  code: string
  name: string
  shape: Hm6GeofenceShape
  enabled: boolean
  centerLatitude: number
  centerLongitude: number
  radiusMeters: number
  vertexCount: number
  eventCount: number
  updatedAt: string
}

export interface TenantGeofenceInput {
  code: string
  name: string
  shape: Hm6GeofenceShape
  centerLatitude: number
  centerLongitude: number
  radiusMeters: number
  vertexCount: number
}

export interface TenantGeofenceEvent {
  id: number
  geofenceId: number
  geofenceName: string
  eventType: Hm6GeofenceEventType
  subjectName: string
  zoneName: string
  accuracyMeters: number
  occurredAt: string
}

export interface TenantSignalInsight {
  id: number
  zoneName: string
  averageRssi: number
  qualityLabel: string
  clientCount: number
}

export interface TenantTrafficInsight {
  id: number
  period: string
  uploadMb: number
  downloadMb: number
  activeClients: number
}

export interface TenantAnalyticsSnapshot {
  averageRssi: number
  totalTrafficMb: number
  peakClients: number
  signals: TenantSignalInsight[]
  traffic: TenantTrafficInsight[]
}
