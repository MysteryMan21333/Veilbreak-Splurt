import { useEffect, useState } from 'react';

import {
  Box,
  Button,
  Input,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';

type ModeWins = Record<string, number>;
type WinStats = Record<string, ModeWins>;

type MapRow = {
  name: string;
  origin: string;
  votable: boolean;
  min: number;
  max: number;
  weight: number;
  tally: number;
  allowed: boolean;
};

type HistoryEntry = {
  time: string;
  ckey: string;
  old_mode: string;
  new_mode: string;
};

type Context = {
  mode: string;
  persisted_override: string | null;
  config_default: string;
  allowed_maps: string[];
  maps: MapRow[];
  wins: WinStats;
  history: HistoryEntry[];
  json_export: string;
  csv_export: string;
};

const MODES = ['STANDARD', 'BROAD'] as const;

const MAP_COLUMNS: { key: keyof MapRow; label: string }[] = [
  { key: 'name', label: 'Name' },
  { key: 'origin', label: 'Origin' },
  { key: 'votable', label: 'Votable' },
  { key: 'min', label: 'Min' },
  { key: 'max', label: 'Max' },
  { key: 'weight', label: 'Weight' },
  { key: 'tally', label: 'Tally' },
  { key: 'allowed', label: 'Allowed' },
];

function sortedWins(wins: ModeWins | undefined): [string, number][] {
  return Object.entries(wins ?? {}).sort((a, b) => b[1] - a[1]);
}

export function VeilbreakMapMode() {
  const { act, data } = useBackend<Context>();
  const [filter, setFilter] = useState('');
  const [sortKey, setSortKey] = useState<keyof MapRow>('name');
  const [sortAsc, setSortAsc] = useState(true);

  useEffect(() => {
    const id = setInterval(() => act('refresh'), 5000);
    return () => clearInterval(id);
  }, [act]);

  const {
    mode,
    persisted_override,
    config_default,
    allowed_maps,
    maps,
    wins,
    history,
    json_export,
    csv_export,
  } = data;

  const filteredMaps = maps
    .filter((m) => m.name.toLowerCase().includes(filter.toLowerCase()))
    .sort((a, b) => {
      const av = String(a[sortKey]);
      const bv = String(b[sortKey]);
      const cmp = av.localeCompare(bv);
      return sortAsc ? cmp : -cmp;
    });

  const copyToClipboard = (text: string) => {
    const clipboard = navigator.clipboard;
    if (clipboard) {
      clipboard.writeText(text).catch(() => {});
    }
  };

  return (
    <Window title="Veilbreak Map Mode" width={950} height={720} theme="admin">
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section
              title="Map Mode"
              buttons={
                <Stack>
                  <Stack.Item>
                    <Button
                      icon="clone"
                      tooltip="Copy JSON to clipboard"
                      onClick={() => copyToClipboard(json_export)}
                    >
                      Copy JSON
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="clone"
                      tooltip="Copy CSV to clipboard"
                      onClick={() => copyToClipboard(csv_export)}
                    >
                      Copy CSV
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="download"
                      tooltip="Write JSON to data/veilbreak_map_mode_export.json"
                      onClick={() => act('export_file', { format: 'json' })}
                    >
                      Export JSON
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="download"
                      tooltip="Write CSV to data/veilbreak_map_mode_export.csv"
                      onClick={() => act('export_file', { format: 'csv' })}
                    >
                      Export CSV
                    </Button>
                  </Stack.Item>
                </Stack>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Current mode">
                  {mode}
                </LabeledList.Item>
                <LabeledList.Item label="Persisted override">
                  {persisted_override ?? '(none, using config default)'}
                </LabeledList.Item>
                <LabeledList.Item label="Config default">
                  {config_default}
                </LabeledList.Item>
                <LabeledList.Item label="Allowed maps">
                  {allowed_maps.length ? allowed_maps.join(', ') : 'None'}
                </LabeledList.Item>
              </LabeledList>
              <Box mt={1}>
                <Stack>
                  {MODES.map((m) => (
                    <Stack.Item key={m}>
                      <Button
                        selected={m === mode}
                        disabled={m === mode}
                        onClick={() => act('flip_mode', { mode: m })}
                      >
                        Switch to {m}
                      </Button>
                    </Stack.Item>
                  ))}
                </Stack>
              </Box>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Stack fill>
              {MODES.map((m) => {
                const entries = sortedWins(wins[m]);
                const total = entries.reduce((sum, [, c]) => sum + c, 0);
                return (
                  <Stack.Item key={m} grow basis={0}>
                    <Section title={`Vote wins — ${m}`}>
                      {entries.length === 0 ? (
                        <NoticeBox>No wins recorded.</NoticeBox>
                      ) : (
                        <Table>
                          <Table.Row header>
                            <Table.Cell>Map</Table.Cell>
                            <Table.Cell collapsing textAlign="right">
                              Wins
                            </Table.Cell>
                            <Table.Cell textAlign="right">Share</Table.Cell>
                          </Table.Row>
                          {entries.map(([map, count]) => (
                            <Table.Row key={map}>
                              <Table.Cell>{map}</Table.Cell>
                              <Table.Cell collapsing textAlign="right">
                                {count}
                              </Table.Cell>
                              <Table.Cell>
                                <ProgressBar
                                  value={total > 0 ? count / total : 0}
                                  minValue={0}
                                  maxValue={1}
                                >
                                  {total > 0
                                    ? `${Math.round((count / total) * 100)}%`
                                    : '0%'}
                                </ProgressBar>
                              </Table.Cell>
                            </Table.Row>
                          ))}
                        </Table>
                      )}
                    </Section>
                  </Stack.Item>
                );
              })}
            </Stack>
          </Stack.Item>

          <Stack.Item grow>
            <Section
              title={`All maps (${filteredMaps.length})`}
              buttons={
                <Input
                  placeholder="Filter maps..."
                  value={filter}
                  onChange={(value) => setFilter(value)}
                />
              }
            >
              <Table>
                <Table.Row header>
                  {MAP_COLUMNS.map((col) => (
                    <Table.Cell
                      key={col.key}
                      onClick={() => {
                        if (sortKey === col.key) {
                          setSortAsc(!sortAsc);
                        } else {
                          setSortKey(col.key);
                          setSortAsc(true);
                        }
                      }}
                    >
                      {col.label}
                      {sortKey === col.key ? (sortAsc ? ' ▲' : ' ▼') : ''}
                    </Table.Cell>
                  ))}
                </Table.Row>
                {filteredMaps.map((m) => (
                  <Table.Row key={m.name}>
                    <Table.Cell>{m.name}</Table.Cell>
                    <Table.Cell>{m.origin}</Table.Cell>
                    <Table.Cell>{m.votable ? 'yes' : 'no'}</Table.Cell>
                    <Table.Cell>{m.min}</Table.Cell>
                    <Table.Cell>{m.max}</Table.Cell>
                    <Table.Cell>{m.weight}</Table.Cell>
                    <Table.Cell>{m.tally}</Table.Cell>
                    <Table.Cell>{m.allowed ? 'yes' : 'no'}</Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title={`Switch history (${history.length})`}>
              {history.length === 0 ? (
                <NoticeBox>No switches recorded.</NoticeBox>
              ) : (
                <Table>
                  <Table.Row header>
                    <Table.Cell>Time</Table.Cell>
                    <Table.Cell>CKey</Table.Cell>
                    <Table.Cell>Old</Table.Cell>
                    <Table.Cell>New</Table.Cell>
                  </Table.Row>
                  {history.map((entry, i) => (
                    <Table.Row key={i}>
                      <Table.Cell>{entry.time}</Table.Cell>
                      <Table.Cell>{entry.ckey}</Table.Cell>
                      <Table.Cell>{entry.old_mode}</Table.Cell>
                      <Table.Cell>{entry.new_mode}</Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
