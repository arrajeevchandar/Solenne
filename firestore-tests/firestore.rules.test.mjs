import fs from 'node:fs';
import path from 'node:path';
import test, { after, before, beforeEach } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'solenne-rules-test';
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(import.meta.dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

function database(uid) {
  return environment.authenticatedContext(uid).firestore();
}

async function seed(callback) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

async function register(uid, username) {
  const db = database(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', uid), {
    displayName: uid,
    username,
    usernameNormalized: username,
  });
  batch.set(doc(db, 'usernames', username), {
    uid,
    username,
    usernameNormalized: username,
    displayName: uid,
    photoUrl: '',
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

function profile(uid, username) {
  return { uid, displayName: uid, username, photoUrl: '' };
}

async function seedAcceptedFriendshipAndJournal() {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'owner', 'journals', 'journal-1'), {
      id: 'journal-1',
      userId: 'owner',
      entryType: 'written',
      title: '',
      prompt: 'Daily reflection',
      recordedAt: new Date('2026-08-12T12:00:00Z'),
      durationSeconds: 0,
      videoUrl: '',
      audioUrl: '',
      writtenText: 'A private reflection selected for sharing.',
      mediaMimeType: 'text/plain',
      thumbnailUrl: '',
      uploadStatus: 'saved',
      analysisStatus: 'complete',
      analysisStep: 'complete',
      analysisVersion: '2026-08-v8-multimodal-journals',
      moodLabel: null,
      aiInsights: [],
      insightProvider: 'groq',
      transcript: {},
    });
    await setDoc(doc(db, 'friendships', 'friend_owner'), {
      requesterId: 'owner',
      recipientId: 'friend',
      memberIds: ['friend', 'owner'],
      status: 'accepted',
      profiles: {
        owner: profile('owner', 'owner_name'),
        friend: profile('friend', 'friend_name'),
      },
    });
  });
}

function validShare(includeTranscript = false) {
  return {
    ownerId: 'owner',
    recipientId: 'friend',
    journalId: 'journal-1',
    friendshipId: 'friend_owner',
    memberIds: ['friend', 'owner'],
    status: 'active',
    includeTranscript,
    ownerProfile: profile('owner', 'owner_name'),
    recipientProfile: profile('friend', 'friend_name'),
    journal: {
      id: 'journal-1',
      userId: 'owner',
      entryType: 'written',
      title: '',
      prompt: 'Daily reflection',
      recordedAt: new Date('2026-08-12T12:00:00Z'),
      durationSeconds: 0,
      videoUrl: '',
      audioUrl: '',
      writtenText: 'A private reflection selected for sharing.',
      mediaMimeType: 'text/plain',
      thumbnailUrl: '',
      uploadStatus: 'saved',
      analysisStatus: 'complete',
      analysisStep: 'complete',
      analysisVersion: '2026-08-v8-multimodal-journals',
      moodLabel: null,
      aiInsights: [],
      insightProvider: 'groq',
    },
    analysisVersion: '2026-08-v8-multimodal-journals',
    sharedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

test('username reservation and profile write are atomic and unique', async () => {
  await assertSucceeds(register('owner', 'quiet_moon'));
  await assertFails(register('other', 'quiet_moon'));
});

test('legacy profile can atomically reserve its generated username', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'legacy-user'), {
      displayName: 'Legacy Friend',
      email: 'legacy@example.com',
      onboardingComplete: true,
    });
  });

  const db = database('legacy-user');
  const batch = writeBatch(db);
  batch.set(
    doc(db, 'users', 'legacy-user'),
    {
      username: 'legacy_friend',
      usernameNormalized: 'legacy_friend',
      consentSource: 'legacy_assumed',
      aiConsentGranted: true,
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(doc(db, 'usernames', 'legacy_friend'), {
    uid: 'legacy-user',
    username: 'legacy_friend',
    usernameNormalized: 'legacy_friend',
    displayName: 'Legacy Friend',
    photoUrl: '',
    updatedAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
});

test('friendships reject outsiders and forged membership', async () => {
  await assertSucceeds(register('owner', 'owner_name'));
  const ownerDb = database('owner');
  await assertFails(
    setDoc(doc(ownerDb, 'friendships', 'forged'), {
      requesterId: 'owner',
      recipientId: 'friend',
      memberIds: ['owner', 'outsider'],
      status: 'pending',
      profiles: {
        owner: profile('owner', 'owner_name'),
        outsider: profile('outsider', 'outsider_name'),
      },
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await seedAcceptedFriendshipAndJournal();
  await assertFails(
    getDoc(doc(database('outsider'), 'friendships', 'friend_owner')),
  );
});

test('friends cannot read the owner private journal', async () => {
  await seedAcceptedFriendshipAndJournal();
  await assertFails(
    getDoc(doc(database('friend'), 'users', 'owner', 'journals', 'journal-1')),
  );
});

test('shares reject raw metrics and transcript without opt-in', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const unsafeMetrics = validShare();
  unsafeMetrics.journal.facial = { confidence: 0.9 };
  await assertFails(
    setDoc(doc(ownerDb, 'journal_shares', 'unsafe-metrics'), unsafeMetrics),
  );

  const unsafeTranscript = validShare();
  unsafeTranscript.journal.transcript = { text: 'Not opted in.' };
  await assertFails(
    setDoc(doc(ownerDb, 'journal_shares', 'unsafe-transcript'), unsafeTranscript),
  );
});

test('sanitized shares are recipient-readable, revocable, and blocked after unfriend', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const shareRef = doc(ownerDb, 'journal_shares', 'owner_journal-1_friend');
  await assertSucceeds(setDoc(shareRef, validShare()));
  await assertSucceeds(
    getDoc(doc(database('friend'), 'journal_shares', shareRef.id)),
  );

  await seed(async (db) => {
    await updateDoc(doc(db, 'friendships', 'friend_owner'), {
      status: 'removed',
    });
  });
  await assertFails(
    getDoc(doc(database('friend'), 'journal_shares', shareRef.id)),
  );
  await assertSucceeds(
    deleteDoc(doc(database('owner'), 'journal_shares', shareRef.id)),
  );
});
